// Builds mock API fixtures for UI tests by running the REAL parser + question generator on the demo PDFs.
// Run: deno run -A tests/e2e/make-fixtures.ts
import { extractText, getDocumentProxy } from 'npm:unpdf@1.9.1';
import { parseReportPages, qualityScore, generateDoctorQuestions, findPreviousComparable } from '../../supabase/functions/_shared/core/index.ts';

const UID = '11111111-aaaa-4aaa-8aaa-000000000001';
const files = ['demo_history_2026-06.pdf', 'demo_history_2026-07.pdf', 'demo_2026-08.pdf'];
const reports: any[] = [];
let n = 1;
for (const f of files) {
  const bytes = await Deno.readFile(new URL(`../../fixtures/demo/${f}`, import.meta.url));
  const { text } = await extractText(await getDocumentProxy(bytes), { mergePages: false });
  const p = parseReportPages(text as string[]);
  const id = `00000000-0000-4000-8000-00000000000${n++}`;
  reports.push({
    id, user_id: UID, title: null, file_path: `${UID}/${id}.pdf`, file_name: `Demo — ${f}`, file_size: bytes.length, status: 'processed',
    error_code: null, error_message: null, report_kind: p.kind, source_system: p.sourceSystem, device: p.device, period_start: p.periodStart,
    period_end: p.periodEnd, period_days: p.periodDays, generated_on: p.generatedOn, name_on_report: p.nameOnReport, page_count: p.pageCount,
    quality: { score: qualityScore(p.checks), checks: p.checks, target_range: p.targetRange }, is_demo: true, created_at: new Date().toISOString(), processed_at: new Date().toISOString(),
    metrics: p.metrics.map((m) => ({ metric_key: m.key, category: m.category, value: m.value, value_text: m.valueText, unit: m.unit, status: m.status, source_page: m.sourcePage, source_label: m.sourceLabel, note: m.note })),
  });
}
const labs = [{ id: 'lab-1', user_id: UID, test_key: 'hba1c', value: 7.4, unit: '%', measured_on: '2026-08-02', source: 'demo', report_id: null, note: 'Synthetic demo value', is_demo: true, created_at: new Date().toISOString() }];
const questions: any[] = [];
for (const r of reports) {
  const prev = findPreviousComparable(r, reports);
  generateDoctorQuestions({ current: r, previous: prev, labs, lang: 'ar' }).forEach((q, i) => questions.push({
    id: `q-${r.id.slice(-2)}-${i}`, user_id: UID, report_id: r.id, rule_key: q.rule_key, question: q.question, rationale: q.rationale, evidence: q.evidence,
    basis: q.basis, is_uncertain: q.is_uncertain, is_saved: i < 2 && r === reports[2], is_edited: false, generated_by: 'rules', position: i, created_at: new Date().toISOString(),
  }));
}
reports.reverse();
await Deno.writeTextFile(new URL('./fixtures.json', import.meta.url), JSON.stringify({ uid: UID, reports, labs, questions }, null, 1));
console.log('reports', reports.length, 'questions', questions.length);
