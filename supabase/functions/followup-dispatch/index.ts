// POST /functions/v1/followup-dispatch
// Body: { "request_id": "<uuid>", "action": "submit" | "retry", "note"?: string }
// 1. "submit" calls the submit_followup RPC AS THE USER (RLS + state machine).
// 2. Builds the minimal pseudonymous payload and records an integration event
//    keyed by an idempotency key, so the same submission is never sent twice.
// 3. Sends it to Make.com when MAKE_WEBHOOK_URL is configured; otherwise records
//    a clearly-labelled local mock event. Never sends health values or names.
import { corsHeaders, error, json, logEvent } from '../_shared/http.ts';
import { env, requireUser, serviceClient, userClient } from '../_shared/clients.ts';
import { dispatchFollowUp, type EventRecord, type EventStore } from '../_shared/dispatch.ts';

function supabaseEventStore(svc: ReturnType<typeof serviceClient>): EventStore {
  return {
    async insertIfAbsent(rec: EventRecord) {
      const { data: inserted } = await svc
        .from('integration_events')
        .upsert(rec, { onConflict: 'idempotency_key', ignoreDuplicates: true })
        .select();
      if (inserted && inserted.length) return { record: inserted[0] as EventRecord, inserted: true };
      const { data } = await svc.from('integration_events').select('*').eq('idempotency_key', rec.idempotency_key).single();
      return { record: data as EventRecord, inserted: false };
    },
    async update(key: string, patch: Partial<EventRecord>) {
      const { data } = await svc
        .from('integration_events')
        .update({ ...patch, last_attempt_at: new Date().toISOString() })
        .eq('idempotency_key', key)
        .select()
        .single();
      return data as EventRecord;
    },
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return error('method_not_allowed', 405);
  const client = userClient(req);
  if (!client || !(await requireUser(client))) return error('unauthorized', 401);

  let body: { request_id?: string; action?: string; note?: string };
  try {
    body = await req.json();
  } catch {
    return error('invalid_json', 400);
  }
  const id = body.request_id;
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return error('invalid_request_id', 400);

  if (body.action === 'submit') {
    const { error: rpcError } = await client.rpc('submit_followup', { p_request_id: id, p_note: body.note ?? null });
    if (rpcError) {
      const m = rpcError.message ?? '';
      return error(m.includes('forbidden') ? 'forbidden' : m.includes('invalid_transition') ? 'invalid_transition' : 'submit_failed',
        m.includes('forbidden') ? 403 : 409);
    }
  } else if (body.action === 'retry') {
    const { data: canView } = await client.rpc('can_view_followup', { p_request_id: id });
    if (canView !== true) return error('forbidden', 403);
  } else {
    return error('invalid_action', 400);
  }

  const svc = serviceClient();
  const { data: row, error: rowError } = await svc
    .from('followup_requests')
    .select('id, pseudo_ref, status, trigger_type, rule_ids, rules_version, updated_at')
    .eq('id', id)
    .single();
  if (rowError || !row) return error('request_not_found', 404);
  const { count } = await svc
    .from('followup_status_history')
    .select('id', { count: 'exact', head: true })
    .eq('request_id', id)
    .eq('to_status', 'awaiting_review');

  const webhookUrl = env('MAKE_WEBHOOK_URL');
  const outcome = await dispatchFollowUp({
    row,
    submissionNumber: Math.max(1, count ?? 1),
    environment: env('SUKKAR_ENVIRONMENT') === 'live' ? 'live' : 'demo',
    make: webhookUrl
      ? { webhookUrl, apiKey: env('MAKE_WEBHOOK_API_KEY'), timeoutMs: 8000, maxAttempts: 3 }
      : null,
    store: supabaseEventStore(svc),
    retry: body.action === 'retry',
  });
  logEvent('followup_dispatch', { state: outcome.state, adapter: outcome.adapter, duplicate: outcome.duplicate });
  return json({ status: row.status, pseudo_ref: row.pseudo_ref, dispatch: outcome });
});
