// Minimal, pseudonymous automation payload. Mirrors buildFollowUpEventPayload
// in packages/sukkar_core/lib/src/integration/followup_notifier.dart.

export interface FollowUpRow {
  id: string;
  pseudo_ref: string;
  status: string;
  trigger_type: string;
  rule_ids: string[];
  rules_version: string;
  updated_at: string;
}

export const FORBIDDEN_PAYLOAD_KEYS = new Set([
  'name', 'display_name', 'national_id', 'dob', 'date_of_birth', 'email', 'phone',
  'user_id', 'metrics', 'snapshot', 'shared_snapshot', 'labs', 'pdf', 'report', 'reason',
]);

export function buildFollowUpEventPayload(row: FollowUpRow, environment: 'demo' | 'live', eventType = 'followup.submitted') {
  const payload = {
    schema_version: 1,
    event_type: eventType,
    request_ref: row.pseudo_ref,
    status: row.status,
    trigger_type: row.trigger_type,
    rule_ids: [...row.rule_ids].sort(),
    rules_version: row.rules_version,
    submitted_at: new Date(row.updated_at).toISOString(),
    environment,
  };
  assertMinimal(payload);
  return payload;
}

export function assertMinimal(payload: Record<string, unknown>) {
  for (const k of Object.keys(payload)) {
    if (FORBIDDEN_PAYLOAD_KEYS.has(k)) throw new Error(`forbidden_payload_key:${k}`);
  }
}
