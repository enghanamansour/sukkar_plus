// chat — Adeed's single persistent assistant. Groq (primary) → Gemini (fallback) via their OpenAI-compatible
// Chat Completions APIs, with controlled, user-scoped data tools.
// POST { message: string, lang?: 'ar'|'en' }   (Authorization: Bearer <user session>)
//
// Security model
//  - GROQ_API_KEY / GEMINI_API_KEY live only in Edge Function secrets.
//  - The model never sees SQL or other users' data. Each tool is a fixed query run through a Supabase client
//    that carries the caller's own session, so Postgres RLS applies to every read.
//  - Emergency / dose-request detection is deterministic and runs even when the AI is unavailable.
import { authenticate, corsHeaders, fail, json, readJson, UUID_RE } from '../_shared/server.ts';
import {
  METRICS, METRIC_BY_KEY, COMPARE_KEYS, checkMessage, compareMetric, compatReasonText, detectSafetyLevel, doseNotice, emergencyNotice,
  findPreviousComparable, isDoseRequest, reportCompatibility, targetText, type StoredReport,
} from '../_shared/core/index.ts';
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';

const MAX_TOOL_ROUNDS = 5;
const HISTORY = 16;

interface Provider { name: 'groq' | 'gemini'; url: string; key: string; model: string }

/** Ordered provider chain: Groq first, Gemini if Groq is missing or fails. */
function providers(): Provider[] {
  const out: Provider[] = [];
  const groq = Deno.env.get('GROQ_API_KEY');
  if (groq) out.push({ name: 'groq', url: 'https://api.groq.com/openai/v1/chat/completions', key: groq, model: Deno.env.get('GROQ_MODEL') ?? 'openai/gpt-oss-120b' });
  const gemini = Deno.env.get('GEMINI_API_KEY');
  if (gemini) out.push({ name: 'gemini', url: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', key: gemini, model: Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.8-flash' });
  return out;
}

type Lang = 'ar' | 'en';

function systemPrompt(lang: Lang, today: string, name: string | null): string {
  const targets = METRICS.filter((m) => m.target).map((m) => `- ${m.label.en} (${m.key}): ${targetText(m.key, 'en')}`).join('\n');
  return `You are Adeed (عضيد), an Arabic-first educational assistant that helps a person with diabetes understand THEIR OWN uploaded diabetes reports, prepare for medical appointments, and learn about diabetes in general.
Adeed is an independent prototype. It is NOT affiliated with, integrated into, or endorsed by Sehhaty or the Saudi Ministry of Health. Never claim otherwise.

Today is ${today}. The signed-in patient's display name: ${name || 'not provided'}.
Default reply language: ${lang === 'ar' ? 'Arabic (clear Modern Standard Arabic, friendly, easy for patients; Western digits)' : 'English'}. If the user writes in or asks for another language (Arabic/English), follow them.

DATA RULES — the most important rules:
1. Facts about the patient come ONLY from the tools. Call list_reports before discussing their data; call get_report_details for the values. Never invent, estimate, or "fill in" a value, date, report, lab result or trend.
2. Respect each value's status: "extracted" (read from the PDF), "calculated" (derived by Adeed — say so), "uncertain" (say clearly it may be wrong and why, using the note), "unavailable" (say it is not in the report). Mention the report period and page when helpful.
3. GMI and HbA1c are different. GMI is calculated from sensor glucose; HbA1c is a lab blood test (get_lab_results). Never call GMI "HbA1c" or "A1C". If there is no lab HbA1c, say so.
4. Only compare reports with compare_reports and follow its compatibility verdict. If it says "limited", state the limitation; if "incompatible" or no earlier report exists, say a comparison is not possible. Never describe a trend from a single report.
5. Reports flagged is_demo are SYNTHETIC demonstration data — say so when you discuss them and never present them as the user's real health data.
6. If information is missing or uncertain, say so plainly and suggest what would help (e.g. ask the clinic for a lab HbA1c, export a 14-day report with CGM active time).

SAFETY RULES:
- You do not diagnose, prescribe, choose insulin doses, calculate corrections, or recommend changing pump/CGM settings or medicines. Explain that these decisions belong to their doctor/diabetes team, and offer to turn the concern into a question for the doctor (save_doctor_question).
- Low glucose questions: give careful general education (common symptoms; that many care plans treat a conscious, able-to-swallow person with fast-acting carbohydrate and a recheck, e.g. the "15-15" approach) while emphasising that their own care plan from their team comes first.
- If a person is unconscious, having a seizure, severely confused, or cannot swallow safely: this is an emergency — call 997 (Saudi Arabia) / local emergency number now, give NOTHING by mouth, use prescribed emergency glucagon only if available and someone knows how, place them on their side. Keep that reply short and do not continue normal chatting first.
- High glucose with vomiting, breathing difficulty, fruity breath, high ketones, chest pain, or confusion needs urgent medical care.
- Never suggest delaying emergency or medical care to keep chatting.

General reference targets (International Consensus on Time in Range 2019, most adults with type 1/type 2; individual targets may differ, e.g. older/high-risk adults or pregnancy):
${targets}
- GMI formula: 3.31 + 0.02392 × mean glucose (mg/dL).

STYLE: Be warm, concise and concrete. Prefer short paragraphs and short bullet lists. Use **bold** sparingly. Explain numbers in everyday terms (e.g. 5% of a day ≈ 1h 12m). End with a helpful next step when natural (a doctor question, or what to check). Do not output raw JSON, IDs or tool names.`;
}

const TOOLS = [
  {
    type: 'function', name: 'list_reports',
    description: "List the patient's uploaded reports (newest first) with period, kind, processing status, demo flag and data-quality score.",
    parameters: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    type: 'function', name: 'get_report_details',
    description: 'Get every extracted metric of one report with value, unit, status (extracted/calculated/uncertain/unavailable), source page, notes and the data-quality checks.',
    parameters: { type: 'object', properties: { report_id: { type: 'string', description: 'Report id from list_reports' } }, required: ['report_id'], additionalProperties: false },
  },
  {
    type: 'function', name: 'compare_reports',
    description: 'Compare a report with an earlier one. If previous_report_id is omitted, the most recent compatible earlier report is chosen. Returns a compatibility verdict and per-metric changes.',
    parameters: {
      type: 'object',
      properties: { report_id: { type: 'string' }, previous_report_id: { type: 'string', description: 'Optional earlier report id' } },
      required: ['report_id'], additionalProperties: false,
    },
  },
  {
    type: 'function', name: 'get_lab_results',
    description: "Get the patient's lab HbA1c results (date, value, source). These are lab tests, distinct from sensor GMI.",
    parameters: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    type: 'function', name: 'get_doctor_questions',
    description: 'Get the questions already prepared for the doctor, optionally for one report.',
    parameters: { type: 'object', properties: { report_id: { type: 'string' } }, additionalProperties: false },
  },
  {
    type: 'function', name: 'save_doctor_question',
    description: "Save a question to the patient's doctor-question list. Only call when the user asks or agrees to save it. The question must be grounded in their data or their stated concern.",
    parameters: {
      type: 'object',
      properties: {
        question: { type: 'string', description: 'Patient-friendly question in the conversation language' },
        rationale: { type: 'string', description: 'Why it matters, citing the actual finding' },
        report_id: { type: 'string', description: 'Related report id, if any' },
        metric_keys: { type: 'array', items: { type: 'string' }, description: 'Metric keys that support the question' },
        is_uncertain: { type: 'boolean', description: 'True if the supporting data is incomplete or uncertain' },
      },
      required: ['question', 'rationale'], additionalProperties: false,
    },
  },
];

async function loadReports(db: SupabaseClient): Promise<(StoredReport & Record<string, any>)[]> {
  const { data, error } = await db.from('reports')
    .select('id, title, file_name, report_kind, status, period_start, period_end, period_days, generated_on, device, source_system, is_demo, quality, created_at, error_message, report_metrics(metric_key, value, unit, status, source_page, source_label, note)')
    .order('period_end', { ascending: false, nullsFirst: false }).order('created_at', { ascending: false }).limit(50);
  if (error) throw error;
  return (data ?? []).map((r: any) => ({ ...r, metrics: r.report_metrics ?? [] }));
}

async function runTool(name: string, rawArgs: string, ctx: { db: SupabaseClient; admin: SupabaseClient; userId: string; lang: Lang }): Promise<unknown> {
  let args: Record<string, any> = {};
  try { args = rawArgs ? JSON.parse(rawArgs) : {}; } catch { return { error: 'invalid arguments' }; }
  const { db, admin, userId, lang } = ctx;
  const idOk = (v: unknown) => typeof v === 'string' && UUID_RE.test(v);

  switch (name) {
    case 'list_reports': {
      const reports = await loadReports(db);
      if (!reports.length) return { reports: [], note: 'The patient has not uploaded any reports yet.' };
      return {
        reports: reports.map((r) => ({
          id: r.id, file_name: r.file_name, kind: r.report_kind, status: r.status, error: r.status === 'failed' ? r.error_message : undefined,
          period_start: r.period_start, period_end: r.period_end, period_days: r.period_days, generated_on: r.generated_on,
          device: r.device, is_demo: r.is_demo, quality: r.quality?.score ?? null,
          headline: Object.fromEntries(['tir', 'tbr_total', 'tar_total', 'gmi', 'hba1c'].map((k) => {
            const m = r.metrics.find((x) => x.metric_key === k); return [k, m ? (m.status === 'unavailable' ? 'unavailable' : `${m.value}${m.unit ?? ''} (${m.status})`) : undefined];
          }).filter(([, v]) => v !== undefined)),
        })),
      };
    }
    case 'get_report_details': {
      if (!idOk(args.report_id)) return { error: 'report_id must be an id from list_reports' };
      const r = (await loadReports(db)).find((x) => x.id === args.report_id);
      if (!r) return { error: 'Report not found for this patient.' };
      return {
        id: r.id, file_name: r.file_name, kind: r.report_kind, status: r.status, is_demo: r.is_demo,
        period: { start: r.period_start, end: r.period_end, days: r.period_days }, generated_on: r.generated_on, device: r.device, source_system: r.source_system,
        metrics: r.metrics.map((m) => ({
          key: m.metric_key, name: METRIC_BY_KEY[m.metric_key]?.label.en ?? m.metric_key, value: m.value, unit: m.unit, status: m.status,
          page: m.source_page, source_text: m.source_label, note: m.note, general_target: targetText(m.metric_key, 'en'),
          category: METRIC_BY_KEY[m.metric_key]?.category,
        })),
        quality_score: r.quality?.score ?? null,
        quality_checks: ((r.quality?.checks ?? []) as any[]).map((c: any) => ({ level: c.level, message: checkMessage(c, lang) })),
        note_on_device_settings: 'Device settings are shown for information only; never suggest changing them.',
      };
    }
    case 'compare_reports': {
      if (!idOk(args.report_id)) return { error: 'report_id must be an id from list_reports' };
      const reports = (await loadReports(db)).filter((r) => r.status === 'processed');
      const current = reports.find((r) => r.id === args.report_id);
      if (!current) return { error: 'Report not found or not processed.' };
      let prev: { report: StoredReport; compat: ReturnType<typeof reportCompatibility> } | null = null;
      if (args.previous_report_id) {
        if (!idOk(args.previous_report_id)) return { error: 'invalid previous_report_id' };
        const p = reports.find((r) => r.id === args.previous_report_id);
        if (!p) return { error: 'Previous report not found.' };
        prev = { report: p, compat: reportCompatibility(current, p) };
      } else prev = findPreviousComparable(current, reports);
      if (!prev) return { comparable: false, reason: 'No earlier report with a compatible, non-overlapping period exists. Do not describe any trend.' };
      if (prev.compat.level === 'incompatible') {
        return { comparable: false, verdict: 'incompatible', reasons: prev.compat.reasons.map((x) => compatReasonText(x, 'en')) };
      }
      return {
        comparable: true, verdict: prev.compat.level, limitations: prev.compat.reasons.map((x) => compatReasonText(x, 'en')),
        current: { id: current.id, period: `${current.period_start} – ${current.period_end}`, days: current.period_days, is_demo: current.is_demo },
        previous: { id: prev.report.id, period: `${prev.report.period_start} – ${prev.report.period_end}`, days: prev.report.period_days },
        metrics: COMPARE_KEYS.map((k) => {
          const c = compareMetric(k, current, prev!.report, prev!.compat);
          return { key: k, name: METRIC_BY_KEY[k]?.label.en, comparable: c.comparable, reason: c.reason, previous: c.previous, current: c.current, unit: c.unit, change: c.delta, direction: c.direction, uncertain: c.uncertain };
        }),
      };
    }
    case 'get_lab_results': {
      const { data } = await db.from('lab_results').select('test_key, value, unit, measured_on, source, is_demo, note').order('measured_on', { ascending: false }).limit(20);
      return { lab_results: data ?? [], note: (data ?? []).length ? undefined : 'No lab HbA1c results recorded.' };
    }
    case 'get_doctor_questions': {
      let q = db.from('doctor_questions').select('question, rationale, basis, is_uncertain, is_saved, report_id').order('position').limit(30);
      if (idOk(args.report_id)) q = q.eq('report_id', args.report_id);
      const { data } = await q;
      return { questions: data ?? [] };
    }
    case 'save_doctor_question': {
      const question = String(args.question ?? '').trim().slice(0, 1000);
      const rationale = String(args.rationale ?? '').trim().slice(0, 2000);
      if (question.length < 3) return { error: 'question is required' };
      let reportId: string | null = null;
      const evidence: unknown[] = [];
      if (args.report_id) {
        if (!idOk(args.report_id)) return { error: 'invalid report_id' };
        const r = (await loadReports(db)).find((x) => x.id === args.report_id);
        if (!r) return { error: 'Report not found for this patient.' };
        reportId = r.id;
        for (const k of (Array.isArray(args.metric_keys) ? args.metric_keys : []).slice(0, 6)) {
          const m = r.metrics.find((x) => x.metric_key === k);
          if (m) evidence.push({ metric_key: k, value: m.value, unit: m.unit, status: m.status, report_id: r.id, source_page: m.source_page, role: 'current' });
        }
      }
      const { count } = await db.from('doctor_questions').select('id', { count: 'exact', head: true });
      const { error } = await admin.from('doctor_questions').insert({
        user_id: userId, report_id: reportId, question, rationale, evidence, basis: evidence.length ? 'finding' : 'custom',
        is_uncertain: Boolean(args.is_uncertain) || !evidence.length, is_saved: true, generated_by: 'assistant', position: (count ?? 0) + 1,
      });
      if (error) return { error: 'Could not save the question.' };
      return { saved: true };
    }
  }
  return { error: `Unknown tool ${name}` };
}

const CHAT_TOOLS = TOOLS.map((t) => ({ type: 'function', function: { name: t.name, description: t.description, parameters: t.parameters } }));

async function callProvider(p: Provider, messages: unknown[]): Promise<any> {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 60_000);
  try {
    const res = await fetch(p.url, {
      method: 'POST', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${p.key}` },
      body: JSON.stringify({ model: p.model, messages, tools: CHAT_TOOLS, tool_choice: 'auto', temperature: 0.3, max_tokens: 2500 }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg = (Array.isArray(data) ? data[0]?.error?.message : data?.error?.message) ?? `HTTP ${res.status}`;
      const err = new Error(`${p.name}: ${msg}`) as Error & { status?: number };
      err.status = res.status;
      throw err;
    }
    return data;
  } finally { clearTimeout(t); }
}

/** Runs one full tool-calling turn on a single provider. Throws if the provider fails. */
async function runTurn(p: Provider, base: unknown[], ctx: { db: SupabaseClient; admin: SupabaseClient; userId: string; lang: Lang }) {
  const messages: any[] = [...base];
  const trace: Array<{ tool: string; args: unknown }> = [];
  for (let round = 0; round <= MAX_TOOL_ROUNDS; round++) {
    const resp = await callProvider(p, messages);
    const msg = resp?.choices?.[0]?.message ?? {};
    const calls: any[] = Array.isArray(msg.tool_calls) ? msg.tool_calls : [];
    if (!calls.length || round === MAX_TOOL_ROUNDS) return { answer: String(msg.content ?? '').trim(), trace };
    messages.push({ role: 'assistant', content: msg.content ?? null, tool_calls: calls });
    for (const c of calls) {
      const name = c.function?.name ?? '';
      const args = c.function?.arguments ?? '{}';
      let result: unknown;
      try { result = await runTool(name, args, ctx); }
      catch (e) { console.error('tool error', name, e); result = { error: 'Tool failed; tell the user the data could not be loaded.' }; }
      trace.push({ tool: name, args: (() => { try { return JSON.parse(args || '{}'); } catch { return {}; } })() });
      messages.push({ role: 'tool', tool_call_id: c.id, content: JSON.stringify(result).slice(0, 30_000) });
    }
  }
  return { answer: '', trace };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return fail(405, 'method_not_allowed', 'Use POST.');

  const auth = await authenticate(req);
  if (auth instanceof Response) return auth;
  const { userId, userClient: db, admin } = auth;

  const body = await readJson<{ message?: string; lang?: string }>(req);
  const message = String(body?.message ?? '').trim();
  if (!message) return fail(400, 'bad_request', 'Message is empty.');
  if (message.length > 2000) return fail(400, 'too_long', 'Message is too long (max 2000 characters).');

  const { data: profile } = await db.from('profiles').select('full_name, preferred_language').eq('id', userId).maybeSingle();
  const lang: Lang = body?.lang === 'en' ? 'en' : body?.lang === 'ar' ? 'ar' : profile?.preferred_language === 'en' ? 'en' : 'ar';

  // Deterministic safety layer — always runs first.
  const safety = detectSafetyLevel(message);
  const dose = isDoseRequest(message);
  const flags: Record<string, unknown> = {};
  if (safety) flags.safety = safety;
  if (dose) flags.dose_request = true;

  const chain = providers();
  if (!chain.length) {
    // Still deliver emergency guidance without the AI.
    return json({
      configured: false,
      error: { code: 'ai_not_configured', message: lang === 'ar' ? 'المساعد الذكي غير مفعّل بعد على الخادم (لم يُضف GROQ_API_KEY أو GEMINI_API_KEY).' : 'The AI assistant is not configured on the server yet (GROQ_API_KEY / GEMINI_API_KEY missing).' },
      safety: safety ? { level: safety, notice: emergencyNotice(safety, lang) } : null,
      dose_notice: dose ? doseNotice(lang) : null,
    }, 503);
  }

  // Simple per-user rate limit: 8 messages per minute.
  const since = new Date(Date.now() - 60_000).toISOString();
  const { count: recent } = await admin.from('chat_messages').select('id', { count: 'exact', head: true })
    .eq('user_id', userId).eq('role', 'user').gte('created_at', since);
  if ((recent ?? 0) >= 8) {
    return json({
      error: { code: 'rate_limited', message: lang === 'ar' ? 'أرسلت رسائل كثيرة خلال دقيقة. انتظر قليلًا ثم حاول مجددًا.' : 'Too many messages in a minute. Please wait a moment.' },
      safety: safety ? { level: safety, notice: emergencyNotice(safety, lang) } : null,
    }, 429);
  }

  const { data: history } = await db.from('chat_messages').select('role, content').order('created_at', { ascending: false }).limit(HISTORY);
  const { data: userRow, error: insErr } = await admin.from('chat_messages')
    .insert({ user_id: userId, role: 'user', content: message, flags }).select('id').single();
  if (insErr) return fail(500, 'db_error', 'Could not save your message.');

  let userTurn = message;
  if (safety === 'emergency') userTurn += '\n\n[System note: the safety layer detected a possible emergency. An emergency notice is already displayed above your reply. Reply briefly, reinforce calling 997 and nothing by mouth, then stop.]';
  if (dose) userTurn += '\n\n[System note: this asks about insulin doses or settings. Do not provide a dose or setting. Offer education and a doctor question instead.]';
  const today = new Date().toISOString().slice(0, 10);
  const base: unknown[] = [
    { role: 'system', content: systemPrompt(lang, today, profile?.full_name ?? null) },
    ...(history ?? []).reverse().map((m: any) => ({ role: m.role, content: m.content })),
    { role: 'user', content: userTurn },
  ];

  let answer = '';
  let trace: Array<{ tool: string; args: unknown }> = [];
  let used: Provider | null = null;
  const errors: string[] = [];
  for (const p of chain) {
    try {
      const r = await runTurn(p, base, { db, admin, userId, lang });
      if (!r.answer) throw new Error(`${p.name}: empty answer`);
      answer = r.answer; trace = r.trace; used = p;
      break;
    } catch (e) {
      console.error('provider failed', p.name, e);
      errors.push(String((e as Error).message ?? e));
    }
  }
  if (!used) {
    await admin.from('chat_messages').delete().eq('id', userRow.id).eq('user_id', userId);
    const msg = lang === 'ar' ? 'تعذّر الوصول للمساعد الآن (Groq وGemini). حاول مرة أخرى بعد قليل.' : 'The assistant is unavailable right now (Groq and Gemini both failed). Please try again shortly.';
    return json({ error: { code: 'ai_error', message: msg }, safety: safety ? { level: safety, notice: emergencyNotice(safety, lang) } : null }, 502);
  }

  if (!answer) answer = lang === 'ar' ? 'عذرًا، لم أتمكن من صياغة رد. حاول إعادة صياغة سؤالك.' : 'Sorry, I could not produce a reply. Please rephrase your question.';
  if (safety) answer = `${emergencyNotice(safety, lang)}\n\n---\n\n${answer}`;
  else if (dose && !/طبيب|doctor|فريق|team/i.test(answer)) answer = `${doseNotice(lang)}\n\n${answer}`;

  const { data: saved } = await admin.from('chat_messages')
    .insert({ user_id: userId, role: 'assistant', content: answer.slice(0, 12000), tool_trace: trace, flags: { ...flags, provider: used.name, model: used.model, fallback: used !== chain[0] } })
    .select('id, role, content, flags, created_at').single();

  return json({ configured: true, message: saved });
});
