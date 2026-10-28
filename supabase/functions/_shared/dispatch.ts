// Orchestrates the follow-up notification with idempotency. Storage is
// injected so the logic can be tested without a database.

import { buildFollowUpEventPayload, type FollowUpRow } from './payload.ts';
import { postToMake, type FetchLike, type MakeConfig } from './make.ts';

export type EventState = 'pending' | 'mock_recorded' | 'sent' | 'failed';

export interface EventRecord {
  idempotency_key: string;
  request_id: string;
  event_type: string;
  adapter: 'make_webhook' | 'local_mock';
  state: EventState;
  attempts: number;
  last_error: string | null;
  payload: Record<string, unknown>;
}

export interface EventStore {
  /** Inserts if absent; returns the stored record (existing or new). */
  insertIfAbsent(rec: EventRecord): Promise<{ record: EventRecord; inserted: boolean }>;
  update(key: string, patch: Partial<EventRecord>): Promise<EventRecord>;
}

export interface DispatchOptions {
  row: FollowUpRow;
  /** Increments each time the request is (re)submitted, e.g. after more info was requested. */
  submissionNumber: number;
  environment: 'demo' | 'live';
  make?: MakeConfig | null;
  store: EventStore;
  fetchImpl?: FetchLike;
  /** true when the caller explicitly asked to retry a failed dispatch. */
  retry?: boolean;
}

export interface DispatchOutcome {
  state: EventState;
  adapter: 'make_webhook' | 'local_mock';
  attempts: number;
  duplicate: boolean;
  error?: string | null;
}

export function idempotencyKeyFor(requestId: string, submissionNumber: number, eventType = 'followup.submitted') {
  return `${requestId}:${eventType}:${submissionNumber}`;
}

export async function dispatchFollowUp(o: DispatchOptions): Promise<DispatchOutcome> {
  const eventType = 'followup.submitted';
  const key = idempotencyKeyFor(o.row.id, o.submissionNumber, eventType);
  const adapter = o.make?.webhookUrl ? 'make_webhook' : 'local_mock';
  const payload = buildFollowUpEventPayload(o.row, o.environment, eventType);

  const { record, inserted } = await o.store.insertIfAbsent({
    idempotency_key: key,
    request_id: o.row.id,
    event_type: eventType,
    adapter,
    state: 'pending',
    attempts: 0,
    last_error: null,
    payload,
  });

  if (!inserted) {
    const done = record.state === 'sent' || record.state === 'mock_recorded';
    if (done || record.state === 'pending' || !o.retry) {
      return { state: record.state, adapter: record.adapter, attempts: record.attempts, duplicate: true, error: record.last_error };
    }
  }

  if (adapter === 'local_mock') {
    const r = await o.store.update(key, { state: 'mock_recorded', attempts: record.attempts + 1, last_error: null });
    return { state: r.state, adapter, attempts: r.attempts, duplicate: false };
  }

  const res = await postToMake(o.make!, payload, key, o.fetchImpl);
  const r = await o.store.update(key, {
    state: res.state,
    attempts: record.attempts + res.attempts,
    last_error: res.error ?? null,
  });
  return { state: r.state, adapter, attempts: r.attempts, duplicate: false, error: r.last_error };
}

/** In-memory store used by tests and local development. */
export class MemoryEventStore implements EventStore {
  records = new Map<string, EventRecord>();
  async insertIfAbsent(rec: EventRecord) {
    const existing = this.records.get(rec.idempotency_key);
    if (existing) return { record: existing, inserted: false };
    this.records.set(rec.idempotency_key, { ...rec });
    return { record: { ...rec }, inserted: true };
  }
  async update(key: string, patch: Partial<EventRecord>) {
    const r = { ...this.records.get(key)!, ...patch };
    this.records.set(key, r);
    return r;
  }
}
