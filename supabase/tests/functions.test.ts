// Tests for the Edge Function shared modules. Pure TypeScript run by Node
// (type stripping); no network, no Deno, no credentials.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkPdfBase64, validateAiExtraction } from '../functions/_shared/validation.ts';
import { allowedNumbersFromContext, guardExplanation } from '../functions/_shared/text_guard.ts';
import { assertMinimal, buildFollowUpEventPayload, FORBIDDEN_PAYLOAD_KEYS } from '../functions/_shared/payload.ts';
import { postToMake } from '../functions/_shared/make.ts';
import { dispatchFollowUp, idempotencyKeyFor, MemoryEventStore } from '../functions/_shared/dispatch.ts';
import {
  AiNotConfiguredError,
  buildExtractionRequest,
  callGemini,
  parseJsonText,
  responseText,
} from '../functions/_shared/gemini.ts';

const row = {
  id: '11111111-1111-4111-8111-111111111111',
  pseudo_ref: 'REQ-ABC123',
  status: 'awaiting_review',
  trigger_type: 'rule',
  rule_ids: ['TBR54-TARGET', 'EPI54-REPEATED'],
  rules_version: '2026.10-demo.1',
  updated_at: '2026-10-28T10:00:00Z',
};

type Call = { url: string; init: RequestInit };
function fakeFetch(responses: Array<number | 'hang' | 'throw'>) {
  const calls: Call[] = [];
  const impl = async (url: string, init: RequestInit): Promise<Response> => {
    calls.push({ url, init });
    const next = responses.shift() ?? 200;
    if (next === 'throw') throw new TypeError('network');
    if (next === 'hang') {
      return new Promise((_, reject) => {
        init.signal?.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })));
      });
    }
    return new Response('{}', { status: next });
  };
  return { impl, calls };
}

// ------------------------------------------------------------ validation

test('AI extraction: valid values pass, malformed ones are dropped with reasons', () => {
  const v = validateAiExtraction({
    glucose_unit: 'mg/dL',
    fields: [
      { key: 'time_in_range', value: 82.8, unit: '%', page: 1, label: 'Time in Range' },
      { key: 'mean_glucose', value: '126', unit: 'mg/dL' },
      { key: 'sd', value: 44.1, unit: 'mmol/L' },
      { key: 'total_insulin', value: 22, unit: 'U' },
      { key: 'cv', value: 135, unit: '%' },
      { key: 'gmi', value: null, unit: '%' },
    ],
  });
  assert.deepEqual(v.fields.map((f) => f.key), ['time_in_range']);
  assert.deepEqual(v.rejected, ['mean_glucose:not_a_number', 'sd:unexpected_unit', 'unknown_key:total_insulin', 'cv:out_of_range']);
});

test('AI extraction: duplicates and non-object responses are rejected', () => {
  const d = validateAiExtraction({ fields: [{ key: 'gmi', value: 6.3, unit: '%' }, { key: 'gmi', value: 6.9, unit: '%' }] });
  assert.equal(d.fields.length, 0);
  assert.deepEqual(d.rejected, ['gmi:duplicate']);
  assert.deepEqual(validateAiExtraction('text').rejected, ['response_not_object']);
  assert.deepEqual(validateAiExtraction([]).rejected, ['response_not_object']);
  assert.deepEqual(validateAiExtraction({}).rejected, ['fields_missing']);
});

test('PDF base64 checks', () => {
  const pdf = Buffer.from('%PDF-1.7\n...%%EOF').toString('base64');
  assert.deepEqual(checkPdfBase64(pdf, 1000), { ok: true, bytes: Math.floor((pdf.length * 3) / 4) });
  assert.deepEqual(checkPdfBase64('', 1000), { ok: false, error: 'empty' });
  assert.deepEqual(checkPdfBase64('**', 1000), { ok: false, error: 'not_base64' });
  assert.deepEqual(checkPdfBase64(Buffer.from('hello world!').toString('base64'), 1000), { ok: false, error: 'not_pdf' });
  assert.deepEqual(checkPdfBase64(pdf, 5), { ok: false, error: 'too_large' });
});

// ------------------------------------------------------------ text guard

test('explanation guard: grounded text passes, dosing/diagnosis/ungrounded numbers fail', () => {
  const ctx = { period: '2026-10-13 — 2026-10-26', period_days: 14, verified_values: [{ label: 'TIR', value: 65.5, unit: '%' }] };
  const allowed = allowedNumbersFromContext(ctx);
  assert.equal(guardExplanation('خلال 14 يومًا كان الوقت ضمن النطاق 65.5%.', allowed).ok, true);
  assert.equal(guardExplanation('الوقت ضمن النطاق ٦٥٫٥%', allowed).ok, true);
  assert.equal(guardExplanation('متوسط السكر 190', allowed).ok, false);
  assert.equal(guardExplanation('زد جرعة الإنسولين', allowed).ok, false);
  assert.equal(guardExplanation('خذ وحدات إنسولين إضافية', allowed).ok, false);
  assert.equal(guardExplanation('Increase your basal dose', allowed).ok, false);
  assert.equal(guardExplanation('هذا تشخيص', allowed).ok, false);
  assert.equal(guardExplanation('', allowed).ok, false);
});

// ------------------------------------------------------------ payload

test('payload is minimal, pseudonymous and sorted', () => {
  const p = buildFollowUpEventPayload(row, 'demo');
  assert.deepEqual(Object.keys(p).sort(), [
    'environment', 'event_type', 'request_ref', 'rule_ids', 'rules_version', 'schema_version', 'status', 'submitted_at', 'trigger_type',
  ]);
  assert.deepEqual(p.rule_ids, ['EPI54-REPEATED', 'TBR54-TARGET']);
  assert.equal(p.request_ref, 'REQ-ABC123');
  assert.ok(!JSON.stringify(p).includes(row.id), 'internal id is not sent');
  for (const k of Object.keys(p)) assert.ok(!FORBIDDEN_PAYLOAD_KEYS.has(k));
  assert.throws(() => assertMinimal({ shared_snapshot: {} }), /forbidden_payload_key/);
});

// ------------------------------------------------------------ Make client

test('Make: sends API key and idempotency headers', async () => {
  const f = fakeFetch([200]);
  const r = await postToMake({ webhookUrl: 'https://hook.example.test/x', apiKey: 'secret' }, { a: 1 }, 'key-1', f.impl);
  assert.equal(r.state, 'sent');
  const h = f.calls[0].init.headers as Record<string, string>;
  assert.equal(h['x-make-apikey'], 'secret');
  assert.equal(h['idempotency-key'], 'key-1');
});

test('Make: retries 5xx and network errors, not 4xx', async () => {
  const a = fakeFetch([500, 'throw', 200]);
  const r1 = await postToMake({ webhookUrl: 'https://h', backoffMs: 1, maxAttempts: 3 }, {}, 'k', a.impl);
  assert.deepEqual([r1.state, r1.attempts], ['sent', 3]);
  const b = fakeFetch([401, 200]);
  const r2 = await postToMake({ webhookUrl: 'https://h', backoffMs: 1 }, {}, 'k', b.impl);
  assert.deepEqual([r2.state, r2.attempts, r2.error], ['failed', 1, 'http_401']);
});

test('Make: times out and reports failure after bounded attempts', async () => {
  const f = fakeFetch(['hang', 'hang']);
  const r = await postToMake({ webhookUrl: 'https://h', timeoutMs: 20, maxAttempts: 2, backoffMs: 1 }, {}, 'k', f.impl);
  assert.deepEqual([r.state, r.attempts, r.error], ['failed', 2, 'timeout']);
});

// ------------------------------------------------------------ dispatch

test('dispatch without Make config records a labelled local mock, idempotently', async () => {
  const store = new MemoryEventStore();
  const first = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'demo', store });
  const again = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'demo', store });
  assert.deepEqual([first.state, first.adapter, first.duplicate], ['mock_recorded', 'local_mock', false]);
  assert.equal(again.duplicate, true);
  assert.equal(store.records.size, 1);
  assert.equal(store.records.get(idempotencyKeyFor(row.id, 1))!.payload.request_ref, 'REQ-ABC123');
});

test('dispatch failure is kept; only an explicit retry sends again; resubmission gets a new key', async () => {
  const store = new MemoryEventStore();
  const make = { webhookUrl: 'https://hook.example.test/x', maxAttempts: 1, backoffMs: 1 };
  const failed = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'live', store, make, fetchImpl: fakeFetch([503]).impl });
  assert.equal(failed.state, 'failed');
  const noRetry = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'live', store, make, fetchImpl: fakeFetch([200]).impl });
  assert.deepEqual([noRetry.state, noRetry.duplicate], ['failed', true]);
  const retried = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'live', store, make, retry: true, fetchImpl: fakeFetch([200]).impl });
  assert.deepEqual([retried.state, retried.attempts], ['sent', 2]);
  const sentAgain = await dispatchFollowUp({ row, submissionNumber: 1, environment: 'live', store, make, retry: true, fetchImpl: fakeFetch([200]).impl });
  assert.equal(sentAgain.duplicate, true, 'a sent event is never re-sent');
  await dispatchFollowUp({ row, submissionNumber: 2, environment: 'live', store, make, fetchImpl: fakeFetch([200]).impl });
  assert.equal(store.records.size, 2);
});

// ------------------------------------------------------------ Gemini

test('Gemini: missing API key raises a typed not-configured error (no network call)', async () => {
  const f = fakeFetch([200]);
  await assert.rejects(callGemini({ apiKey: undefined }, {}, f.impl), AiNotConfiguredError);
  assert.equal(f.calls.length, 0);
});

test('Gemini: request carries the PDF inline with a JSON schema; key goes in a header', async () => {
  const body = buildExtractionRequest('JVBERi0=');
  const parts = body.contents[0].parts as Array<Record<string, unknown>>;
  assert.deepEqual(parts[0], { inline_data: { mime_type: 'application/pdf', data: 'JVBERi0=' } });
  assert.equal(body.generationConfig.responseMimeType, 'application/json');
  assert.equal(body.generationConfig.temperature, 0);
  const calls: Call[] = [];
  const impl = async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: '```json\n{"fields":[]}\n```' }] } }] }), { status: 200 });
  };
  const raw = await callGemini({ apiKey: 'k', model: 'gemini-3.8-flash' }, body, impl);
  assert.match(calls[0].url, /models\/gemini-3\.8-flash:generateContent$/);
  assert.equal((calls[0].init.headers as Record<string, string>)['x-goog-api-key'], 'k');
  assert.ok(!calls[0].url.includes('key='), 'API key is not placed in the URL');
  assert.deepEqual(parseJsonText(responseText(raw)), { fields: [] });
});

test('Gemini: HTTP errors and unparsable output are surfaced, not trusted', async () => {
  const impl = async () => new Response('busy', { status: 503 });
  await assert.rejects(callGemini({ apiKey: 'k' }, {}, impl), /gemini_http_503/);
  assert.equal(parseJsonText('not json'), null);
  assert.equal(responseText({}), null);
});
