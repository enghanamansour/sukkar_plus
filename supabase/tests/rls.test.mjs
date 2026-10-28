// Runs the real migrations on PGlite (Postgres compiled to WebAssembly) with a
// minimal emulation of Supabase's roles, auth schema and default grants, then
// checks Row Level Security and the follow-up RPCs.
//
//   cd supabase/tests && npm install && npm test
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(here, '..', 'migrations');

const A = '00000000-0000-4000-8000-00000000000a';
const B = '00000000-0000-4000-8000-00000000000b';
const R = '00000000-0000-4000-8000-0000000000ff';

const SUPABASE_EMULATION = `
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
-- Supabase grants broad default privileges in "public"; RLS and our revokes must hold anyway.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
`;

let db;

async function as(sub, role, fn) {
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [sub ?? '']);
  await db.exec(`set role ${role}`);
  try {
    return await fn();
  } finally {
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claim.sub', '', false)`);
  }
}
const patient = (id, fn) => as(id, 'authenticated', fn);
const reviewer = (fn) => as(R, 'authenticated', fn);
const anon = (fn) => as(null, 'anon', fn);

async function rejects(promise, pattern) {
  await assert.rejects(promise, (e) => {
    assert.match(String(e.message), pattern);
    return true;
  });
}

async function newDraft(owner, key = 'k1') {
  return patient(owner, async () => {
    await db.query(
      `insert into public.followup_requests (user_id, trigger_type, rule_ids, rules_version, reason, shared_snapshot, idempotency_key, provenance)
       values (auth.uid(), 'rule', '{TBR54-TARGET}', '2026.10-demo.1', 'reason', '{"items":{}}', $1, 'synthetic')`,
      [key],
    );
    const r = await db.query(`select id from public.followup_requests where status = 'draft' order by created_at desc limit 1`);
    return r.rows[0].id;
  });
}

before(async () => {
  db = new PGlite();
  await db.exec(SUPABASE_EMULATION);
  for (const f of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
    await db.exec(readFileSync(join(migrationsDir, f), 'utf8'));
  }
  await db.exec(`insert into auth.users (id, email) values ('${A}', 'a@example.test'), ('${B}', 'b@example.test'), ('${R}', 'r@example.test')`);
  await db.exec(`update public.profiles set role = 'reviewer' where id = '${R}'`); // admin action
});

test('signup trigger creates a patient profile with a pseudonymous id', async () => {
  const r = await db.query(`select role, pseudo_id from public.profiles where id = $1`, [A]);
  assert.equal(r.rows[0].role, 'patient');
  assert.match(r.rows[0].pseudo_id, /^SP-[0-9A-F]{6}$/);
});

test('patients only see their own laboratory results; reviewers and anon see none', async () => {
  await patient(A, () =>
    db.query(`insert into public.lab_results (user_id, test_code, test_name, value, unit, collection_date, source, verification_status, provenance)
              values (auth.uid(), 'hba1c', 'HbA1c', 7.1, '%', '2026-10-20', 'manual', 'verified', 'synthetic')`));
  assert.equal((await patient(A, () => db.query('select * from public.lab_results'))).rows.length, 1);
  assert.equal((await patient(B, () => db.query('select * from public.lab_results'))).rows.length, 0);
  assert.equal((await reviewer(() => db.query('select * from public.lab_results'))).rows.length, 0);
  await rejects(anon(() => db.query('select * from public.lab_results')), /permission denied/);
});

test('a patient cannot insert rows for another user', async () => {
  await rejects(
    patient(B, () =>
      db.query(`insert into public.lab_results (user_id, test_code, test_name, value, unit, source, verification_status, provenance)
                values ($1, 'ldl', 'LDL', 100, 'mg/dL', 'manual', 'verified', 'synthetic')`, [A])),
    /row-level security/,
  );
});

test('HbA1c unit and missing-value constraints hold at the database level', async () => {
  await rejects(
    patient(A, () =>
      db.query(`insert into public.lab_results (user_id, test_code, test_name, value, unit, source, verification_status, provenance)
                values (auth.uid(), 'hba1c', 'HbA1c', 7.1, 'mg/dL', 'manual', 'verified', 'real')`)),
    /check constraint/,
  );
  const rep = await patient(A, () =>
    db.query(`insert into public.device_reports (user_id, provenance, source_type) values (auth.uid(), 'synthetic', 'demo_fixture') returning id`));
  await rejects(
    patient(A, () =>
      db.query(`insert into public.verified_metrics (report_id, user_id, metric_key, value, unit, origin, verification_status)
                values ($1, auth.uid(), 'gmi', null, '%', 'extracted_from_report', 'verified')`, [rep.rows[0].id])),
    /check constraint/,
  );
});

test('users cannot change their own role but can set their target profile', async () => {
  await rejects(patient(A, () => db.query(`update public.profiles set role = 'reviewer' where id = auth.uid()`)), /permission denied/);
  await patient(A, () => db.query(`update public.profiles set target_profile = 'general_adult_t1_t2' where id = auth.uid()`));
  const r = await db.query(`select role, target_profile from public.profiles where id = $1`, [A]);
  assert.deepEqual(r.rows[0], { role: 'patient', target_profile: 'general_adult_t1_t2' });
});

test('appointments are read-only for patients (simulated only)', async () => {
  await rejects(
    patient(A, () => db.query(`insert into public.appointments (user_id, scheduled_at, clinic_label, provenance) values (auth.uid(), now(), 'x', 'real')`)),
    /permission denied/,
  );
});

test('follow-up workflow: draft hidden from reviewer, RPC transitions, patient sees decision', async () => {
  const id = await newDraft(A, 'flow-1');
  assert.equal((await reviewer(() => db.query('select id from public.followup_requests'))).rows.length, 0);

  // direct status update is not possible
  await rejects(patient(A, () => db.query(`update public.followup_requests set status = 'reviewed' where id = $1`, [id])), /permission denied/);

  assert.equal((await patient(A, () => db.query('select public.submit_followup($1) as s', [id]))).rows[0].s, 'awaiting_review');
  const seen = await reviewer(() => db.query('select id, pseudo_ref, shared_snapshot, status from public.followup_requests'));
  assert.equal(seen.rows.length, 1);
  assert.match(seen.rows[0].pseudo_ref, /^REQ-/);

  // reviewers cannot read the patient's user id
  await rejects(reviewer(() => db.query('select user_id from public.followup_requests')), /permission denied/);

  // patients cannot act as reviewers
  await rejects(patient(A, () => db.query('select public.reviewer_start_review($1)', [id])), /forbidden/);
  // a decision needs a started review
  await rejects(reviewer(() => db.query(`select public.reviewer_decide($1, 'review_required', null)`, [id])), /invalid_transition/);

  await reviewer(() => db.query('select public.reviewer_start_review($1)', [id]));
  await reviewer(() => db.query(`select public.reviewer_decide($1, 'review_required', 'ملاحظة تجريبية')`, [id]));

  const mine = await patient(A, () => db.query('select status, decision from public.followup_requests where id = $1', [id]));
  assert.deepEqual(mine.rows[0], { status: 'reviewed', decision: 'review_required' });
  const notes = await patient(A, () => db.query('select author_label, body from public.review_notes where request_id = $1', [id]));
  assert.equal(notes.rows[0].body, 'ملاحظة تجريبية');
  const hist = await patient(A, () => db.query('select from_status, to_status, actor_role from public.followup_status_history where request_id = $1 order by created_at', [id]));
  assert.deepEqual(hist.rows.map((h) => `${h.from_status}>${h.to_status}:${h.actor_role}`), [
    'draft>awaiting_review:patient',
    'awaiting_review>under_review:reviewer',
    'under_review>reviewed:reviewer',
  ]);
  assert.equal((await patient(B, () => db.query('select id from public.followup_requests'))).rows.length, 0);
  assert.equal((await patient(A, () => db.query('select public.close_followup($1) as s', [id]))).rows[0].s, 'closed');
});

test('data-completion decision returns the request to the patient', async () => {
  const id = await newDraft(A, 'flow-2');
  await patient(A, () => db.query('select public.submit_followup($1)', [id]));
  await reviewer(() => db.query('select public.reviewer_start_review($1)', [id]));
  assert.equal((await reviewer(() => db.query(`select public.reviewer_decide($1, 'data_completion', null) as s`, [id]))).rows[0].s, 'more_info_requested');
  assert.equal((await patient(A, () => db.query('select public.submit_followup($1, $2) as s', [id, 'تمت الإضافة']))).rows[0].s, 'awaiting_review');
});

test('another patient cannot submit or withdraw someone else\'s request', async () => {
  const id = await newDraft(A, 'flow-3');
  await rejects(patient(B, () => db.query('select public.submit_followup($1)', [id])), /forbidden/);
  await rejects(patient(B, () => db.query('select public.withdraw_followup($1)', [id])), /forbidden/);
});

test('duplicate open requests are blocked; closed ones do not block', async () => {
  const id = await newDraft(A, 'dup-key');
  await rejects(newDraft(A, 'dup-key'), /duplicate key/);
  await patient(A, () => db.query('select public.withdraw_followup($1)', [id]));
  const again = await newDraft(A, 'dup-key');
  assert.ok(again);
});

test('drafts cannot be inserted in a non-draft state', async () => {
  await rejects(
    patient(A, () =>
      db.query(`insert into public.followup_requests (user_id, trigger_type, rules_version, reason, shared_snapshot, idempotency_key, provenance)
                values (auth.uid(), 'rule', 'v', 'r', '{}', 'x-status', 'real')`).then(() =>
        db.query(`insert into public.followup_requests (user_id, trigger_type, rules_version, reason, shared_snapshot, idempotency_key, provenance, status)
                  values (auth.uid(), 'rule', 'v', 'r', '{}', 'x-status-2', 'real', 'reviewed')`))),
    /permission denied|row-level security/,
  );
});

test('integration events are written by the backend only, readable by those who can view the request', async () => {
  const id = await newDraft(A, 'evt');
  await rejects(
    patient(A, () => db.query(`insert into public.integration_events (request_id, event_type, idempotency_key, adapter, state, payload) values ($1, 'x', 'evt-1', 'local_mock', 'mock_recorded', '{}')`, [id])),
    /permission denied/,
  );
  await db.query(`insert into public.integration_events (request_id, event_type, idempotency_key, adapter, state, payload) values ($1, 'followup.submitted', 'evt-1', 'local_mock', 'mock_recorded', '{}')`, [id]);
  await rejects(
    db.query(`insert into public.integration_events (request_id, event_type, idempotency_key, adapter, state, payload) values ($1, 'followup.submitted', 'evt-1', 'local_mock', 'mock_recorded', '{}')`, [id]),
    /duplicate key/,
  );
  assert.equal((await patient(A, () => db.query('select state from public.integration_events where request_id = $1', [id]))).rows.length, 1);
  await rejects(patient(A, () => db.query('select payload from public.integration_events')), /permission denied/);
});

test('anonymous users cannot call RPCs; internal helper is not callable', async () => {
  await rejects(anon(() => db.query(`select public.submit_followup('${A}')`)), /permission denied/);
  await rejects(patient(A, () => db.query(`select public._followup_move('${A}', '{draft}', 'closed', 'patient', null)`)), /permission denied/);
});

test('synthetic seed.sql runs and the reviewer sees only the submitted request', async () => {
  const P = '00000000-0000-4000-8000-0000000000c1';
  const RV = '00000000-0000-4000-8000-0000000000c2';
  await db.exec(`insert into auth.users (id, email) values ('${P}', 'demo-patient@example.com'), ('${RV}', 'demo-reviewer@example.com')`);
  await db.exec(readFileSync(join(here, '..', 'seed.sql'), 'utf8'));
  const role = await db.query('select role from public.profiles where id = $1', [RV]);
  assert.equal(role.rows[0].role, 'reviewer');
  const queue = await as(RV, 'authenticated', () => db.query(`select pseudo_ref, status from public.followup_requests where status = 'awaiting_review'`));
  assert.ok(queue.rows.length >= 1);
  const labs = await as(P, 'authenticated', () => db.query('select unit from public.lab_results order by collection_date'));
  assert.deepEqual(labs.rows.map((r) => r.unit), ['%', 'mmol/mol']);
});

test('delete_my_data removes only the caller\'s rows', async () => {
  await patient(B, () =>
    db.query(`insert into public.lab_results (user_id, test_code, test_name, value, unit, source, verification_status, provenance)
              values (auth.uid(), 'ldl', 'LDL', 100, 'mg/dL', 'manual', 'verified', 'synthetic')`));
  await patient(A, () => db.query('select public.delete_my_data()'));
  assert.equal((await db.query('select count(*)::int as n from public.lab_results where user_id = $1', [A])).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int as n from public.followup_requests where user_id = $1', [A])).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int as n from public.lab_results where user_id = $1', [B])).rows[0].n, 1);
});
