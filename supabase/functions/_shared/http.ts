// HTTP helpers for Edge Functions. Error bodies carry stable codes the app
// maps to Arabic messages; they never echo health data.

export const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'content-type': 'application/json' } });
}

export function error(code: string, status: number): Response {
  return json({ error: code }, status);
}

/** Logs an event name and non-sensitive metadata only. */
export function logEvent(name: string, meta: Record<string, string | number | boolean> = {}) {
  console.log(JSON.stringify({ event: name, ...meta }));
}
