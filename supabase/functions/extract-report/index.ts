// POST /functions/v1/extract-report
// Body: { "pdf_base64": "<base64>" }
// Sends the PDF to Gemini ONLY when the user has an active consent that allows
// external AI processing. The PDF is not stored. Output is validated before it
// is returned, and the app still reconciles it with local extraction and asks
// the user to confirm every value.
import { corsHeaders, error, json, logEvent } from '../_shared/http.ts';
import { env, requireUser, userClient } from '../_shared/clients.ts';
import { AiNotConfiguredError, DEFAULT_GEMINI_MODEL, buildExtractionRequest, callGemini, parseJsonText, responseText } from '../_shared/gemini.ts';
import { checkPdfBase64, validateAiExtraction } from '../_shared/validation.ts';

const MAX_PDF_BYTES = 15 * 1024 * 1024;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return error('method_not_allowed', 405);

  const client = userClient(req);
  const user = await requireUser(client);
  if (!user || !client) return error('unauthorized', 401);

  const { data: consent } = await client
    .from('consents')
    .select('id')
    .eq('allows_external_ai', true)
    .is('revoked_at', null)
    .limit(1);
  if (!consent || consent.length === 0) return error('consent_required', 403);

  let body: { pdf_base64?: unknown };
  try {
    body = await req.json();
  } catch {
    return error('invalid_json', 400);
  }
  const check = checkPdfBase64(body.pdf_base64, MAX_PDF_BYTES);
  if (!check.ok) return error(`invalid_pdf:${check.error}`, 400);

  const model = env('GEMINI_MODEL') ?? DEFAULT_GEMINI_MODEL;
  try {
    const raw = await callGemini({ apiKey: env('GEMINI_API_KEY'), model }, buildExtractionRequest(body.pdf_base64 as string));
    const parsed = parseJsonText(responseText(raw));
    const validated = validateAiExtraction(parsed);
    logEvent('extract_report', { fields: validated.fields.length, rejected: validated.rejected.length });
    return json({ provider: 'gemini', model, ...validated });
  } catch (e) {
    if (e instanceof AiNotConfiguredError) return error('ai_not_configured', 503);
    logEvent('extract_report_failed', { reason: (e as Error).message.slice(0, 40) });
    return error('ai_unavailable', 502);
  }
});
