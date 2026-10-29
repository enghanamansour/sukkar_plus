// process-report — extracts metrics from an uploaded PDF and generates doctor questions.
// POST { report_id: uuid, action?: 'process' | 'regenerate_questions' }   (Authorization: Bearer <user session>)
import { extractText, getDocumentProxy } from 'npm:unpdf@1.9.1';
import { authenticate, corsHeaders, fail, json, readJson, UUID_RE } from '../_shared/server.ts';
import {
  findPreviousComparable, generateDoctorQuestions, namesLikelyMatch, parseReportPages, qualityScore, ReportParseError,
  type QualityCheck, type StoredReport, type LabResult,
} from '../_shared/core/index.ts';
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';

const STALE_MS = 3 * 60 * 1000;

async function loadUserReports(admin: SupabaseClient, userId: string): Promise<StoredReport[]> {
  const { data, error } = await admin
    .from('reports')
    .select('id, report_kind, status, period_start, period_end, period_days, is_demo, file_name, quality, report_metrics(metric_key, value, unit, status, source_page, source_label, note)')
    .eq('user_id', userId)
    .eq('status', 'processed');
  if (error) throw error;
  return (data ?? []).map((r: any) => ({ ...r, metrics: r.report_metrics ?? [] }));
}

async function regenerateQuestions(admin: SupabaseClient, userId: string, reportId: string, lang: 'ar' | 'en'): Promise<number> {
  const reports = await loadUserReports(admin, userId);
  const current = reports.find((r) => r.id === reportId);
  if (!current) return 0;
  const { data: labs } = await admin.from('lab_results').select('value, measured_on, source, is_demo').eq('user_id', userId);
  const previous = findPreviousComparable(current, reports);
  const qs = generateDoctorQuestions({ current, previous, labs: (labs ?? []) as LabResult[], lang });
  // Keep anything the patient saved or edited; replace only untouched generated questions.
  const { data: kept } = await admin.from('doctor_questions').select('rule_key')
    .eq('user_id', userId).eq('report_id', reportId).eq('generated_by', 'rules').or('is_saved.eq.true,is_edited.eq.true');
  const keptKeys = new Set((kept ?? []).map((k: any) => k.rule_key));
  await admin.from('doctor_questions').delete()
    .eq('user_id', userId).eq('report_id', reportId).eq('generated_by', 'rules').eq('is_saved', false).eq('is_edited', false);
  const rows = qs.filter((q) => !keptKeys.has(q.rule_key)).map((q, i) => ({
    user_id: userId, report_id: reportId, rule_key: q.rule_key, question: q.question, rationale: q.rationale,
    evidence: q.evidence, basis: q.basis, is_uncertain: q.is_uncertain, generated_by: 'rules', position: i,
  }));
  if (rows.length) {
    const { error } = await admin.from('doctor_questions').insert(rows);
    if (error) throw error;
  }
  return rows.length;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return fail(405, 'method_not_allowed', 'Use POST.');

  const auth = await authenticate(req);
  if (auth instanceof Response) return auth;
  const { userId, userClient, admin } = auth;

  const body = await readJson<{ report_id?: string; action?: string }>(req);
  if (!body?.report_id || !UUID_RE.test(body.report_id)) return fail(400, 'bad_request', 'report_id is required.');
  const action = body.action === 'regenerate_questions' ? 'regenerate_questions' : 'process';

  // Read through the user's own client: RLS guarantees the report belongs to the caller.
  const { data: report, error: rErr } = await userClient.from('reports').select('*').eq('id', body.report_id).maybeSingle();
  if (rErr) return fail(500, 'db_error', 'Could not load the report.');
  if (!report) return fail(404, 'not_found', 'Report not found.');

  const { data: profile } = await userClient.from('profiles').select('full_name, preferred_language').eq('id', userId).maybeSingle();
  const lang: 'ar' | 'en' = profile?.preferred_language === 'en' ? 'en' : 'ar';

  if (action === 'regenerate_questions') {
    if (report.status !== 'processed') return fail(409, 'not_processed', 'The report has not been processed yet.');
    try {
      const n = await regenerateQuestions(admin, userId, report.id, lang);
      return json({ ok: true, questions_created: n });
    } catch (e) {
      console.error('regenerate failed', e);
      return fail(500, 'questions_failed', 'Could not generate questions.');
    }
  }

  if (report.status === 'processing' && Date.now() - Date.parse(report.processed_at ?? report.created_at) < STALE_MS) {
    return fail(409, 'in_progress', 'This report is already being processed.');
  }

  const setFailed = async (code: string, message: string) => {
    await admin.from('reports').update({ status: 'failed', error_code: code, error_message: message, processed_at: new Date().toISOString() })
      .eq('id', report.id).eq('user_id', userId);
    return fail(422, code, message);
  };

  await admin.from('reports').update({ status: 'processing', error_code: null, error_message: null, processed_at: new Date().toISOString() })
    .eq('id', report.id).eq('user_id', userId);

  // Download through the user's client: storage RLS limits it to the caller's own folder.
  const { data: blob, error: dErr } = await userClient.storage.from('reports').download(report.file_path);
  if (dErr || !blob) return await setFailed('file_missing', 'The uploaded file could not be found. Please upload it again.');
  const bytes = new Uint8Array(await blob.arrayBuffer());
  if (bytes.length > 10 * 1024 * 1024) return await setFailed('too_large', 'The file is larger than 10 MB.');
  if (!(bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46)) {
    return await setFailed('not_pdf', 'This file is not a valid PDF.');
  }

  let pages: string[];
  try {
    const pdf = await getDocumentProxy(bytes);
    const { text } = await extractText(pdf, { mergePages: false });
    pages = (text as string[]).slice(0, 60);
  } catch (e) {
    console.error('pdf read failed', e);
    return await setFailed('unreadable_pdf', 'The PDF could not be read. It may be damaged or password-protected.');
  }

  let parsed;
  try {
    parsed = parseReportPages(pages);
  } catch (e) {
    if (e instanceof ReportParseError) {
      return await setFailed(e.code, e.code === 'no_text'
        ? 'This PDF has no readable text (it may be a scanned image). Please export the report from your device app as a PDF.'
        : 'No diabetes report metrics were found in this PDF.');
    }
    console.error('parse failed', e);
    return await setFailed('parse_error', 'The report could not be processed.');
  }

  const checks: QualityCheck[] = [...parsed.checks];
  if (!report.is_demo && namesLikelyMatch(profile?.full_name, parsed.nameOnReport) === false) {
    checks.push({ key: 'name_mismatch', level: 'warn', params: { name: parsed.nameOnReport } });
  }
  if (parsed.periodStart && parsed.periodEnd) {
    const { data: dup } = await admin.from('reports').select('id').eq('user_id', userId).eq('status', 'processed')
      .eq('is_demo', report.is_demo).eq('period_start', parsed.periodStart).eq('period_end', parsed.periodEnd).neq('id', report.id).limit(1);
    if (dup?.length) checks.push({ key: 'duplicate_period', level: 'warn', params: { other: dup[0].id } });
  }
  const hba1c = parsed.metrics.find((m) => m.key === 'hba1c' && m.value != null);
  const labDate = parsed.generatedOn ?? parsed.periodEnd;
  if (parsed.kind === 'lab' && hba1c && !labDate) checks.push({ key: 'lab_date_missing', level: 'warn' });

  // Replace any previous extraction of this report (re-processing is idempotent).
  await admin.from('report_metrics').delete().eq('report_id', report.id).eq('user_id', userId);
  await admin.from('lab_results').delete().eq('report_id', report.id).eq('user_id', userId).eq('source', 'report');

  const metricRows = parsed.metrics.map((m) => ({
    report_id: report.id, user_id: userId, metric_key: m.key, category: m.category, value: m.value, value_text: m.valueText,
    unit: m.unit, status: m.status, source_page: m.sourcePage, source_label: m.sourceLabel, note: m.note,
  }));
  const { error: mErr } = await admin.from('report_metrics').insert(metricRows);
  if (mErr) { console.error(mErr); return await setFailed('db_error', 'Could not save the extracted values.'); }

  if (parsed.kind === 'lab' && hba1c && labDate) {
    await admin.from('lab_results').insert({
      user_id: userId, test_key: 'hba1c', value: hba1c.value, unit: '%', measured_on: labDate, source: 'report', report_id: report.id, is_demo: report.is_demo,
    });
  }

  const quality = {
    score: qualityScore(checks), checks, target_range: parsed.targetRange, date_order: parsed.dateOrder, stated_days: parsed.statedDays,
  };
  const { error: uErr } = await admin.from('reports').update({
    status: 'processed', report_kind: parsed.kind, source_system: parsed.sourceSystem, device: parsed.device,
    name_on_report: parsed.nameOnReport, generated_on: parsed.generatedOn, period_start: parsed.periodStart,
    period_end: parsed.periodEnd, period_days: parsed.periodDays, page_count: parsed.pageCount, quality,
    processed_at: new Date().toISOString(), error_code: null, error_message: null,
  }).eq('id', report.id).eq('user_id', userId);
  if (uErr) { console.error(uErr); return await setFailed('db_error', 'Could not save the report.'); }

  let questions = 0;
  try { questions = await regenerateQuestions(admin, userId, report.id, lang); } catch (e) { console.error('questions failed', e); }

  return json({ ok: true, report_id: report.id, kind: parsed.kind, metrics: metricRows.length, questions_created: questions, quality: quality.score });
});
