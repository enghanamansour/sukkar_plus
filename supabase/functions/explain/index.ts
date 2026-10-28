// POST /functions/v1/explain
// Body: { "context": { topic, period, period_days, verified_values: [{label, value, unit}], missing, outcome } }
// Returns { source: "ai", text } only when the text passes the safety and
// grounding guard; otherwise 422 so the app falls back to its local template.
import { corsHeaders, error, json, logEvent } from '../_shared/http.ts';
import { env, requireUser, userClient } from '../_shared/clients.ts';
import { AiNotConfiguredError, DEFAULT_GEMINI_MODEL, buildExplanationRequest, callGemini, responseText } from '../_shared/gemini.ts';
import { allowedNumbersFromContext, guardExplanation } from '../_shared/text_guard.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return error('method_not_allowed', 405);
  const client = userClient(req);
  if (!(await requireUser(client))) return error('unauthorized', 401);

  let body: { context?: Record<string, unknown> };
  try {
    body = await req.json();
  } catch {
    return error('invalid_json', 400);
  }
  const ctx = body.context;
  if (!ctx || typeof ctx !== 'object' || !Array.isArray(ctx.verified_values) || ctx.verified_values.length > 40) {
    return error('invalid_context', 400);
  }

  try {
    const model = env('GEMINI_MODEL') ?? DEFAULT_GEMINI_MODEL;
    const raw = await callGemini({ apiKey: env('GEMINI_API_KEY'), model }, buildExplanationRequest(ctx));
    const text = responseText(raw) ?? '';
    const guard = guardExplanation(text, allowedNumbersFromContext(ctx));
    if (!guard.ok) {
      logEvent('explain_rejected', { reasons: guard.reasons.length });
      return json({ error: 'ai_output_rejected' }, 422);
    }
    return json({ source: 'ai', model, text });
  } catch (e) {
    if (e instanceof AiNotConfiguredError) return error('ai_not_configured', 503);
    return error('ai_unavailable', 502);
  }
});
