-- Sukkar Plus — Row Level Security and workflow RPCs
-- Principles:
--   * patients read/write only their own rows;
--   * reviewers never read patient tables directly — only submitted follow-up
--     requests (the shared snapshot the patient approved), without user_id;
--   * follow-up status changes happen only through the RPCs below, which
--     enforce the state machine and roles;
--   * integration_events are written only by the backend (service role).

create or replace function public.is_reviewer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'reviewer');
$$;

alter table public.profiles enable row level security;
alter table public.patient_identities enable row level security;
alter table public.consents enable row level security;
alter table public.device_reports enable row level security;
alter table public.extracted_fields enable row level security;
alter table public.analysis_runs enable row level security;
alter table public.verified_metrics enable row level security;
alter table public.lab_results enable row level security;
alter table public.historical_comparisons enable row level security;
alter table public.appointments enable row level security;
alter table public.test_reminders enable row level security;
alter table public.visit_summaries enable row level security;
alter table public.followup_requests enable row level security;
alter table public.followup_status_history enable row level security;
alter table public.review_notes enable row level security;
alter table public.integration_events enable row level security;

-- No access at all for anonymous clients.
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon, public;

-- profiles: read own; update only target_profile (role is not updatable).
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.profiles from authenticated;
grant select on public.profiles to authenticated;
grant update (target_profile) on public.profiles to authenticated;

-- Owner-only tables.
do $$
declare t text;
begin
  foreach t in array array[
    'patient_identities', 'consents', 'device_reports', 'extracted_fields', 'analysis_runs',
    'verified_metrics', 'lab_results', 'historical_comparisons', 'appointments',
    'test_reminders', 'visit_summaries'
  ] loop
    execute format(
      'create policy %1$s_owner_all on public.%1$s for all to authenticated using (%2$s = auth.uid()) with check (%2$s = auth.uid())',
      t, case when t = 'patient_identities' then 'user_id' else 'user_id' end);
    execute format('grant select, insert, update, delete on public.%s to authenticated', t);
  end loop;
end $$;

-- Appointments are simulated and read-only for patients in the prototype.
revoke insert, update, delete on public.appointments from authenticated;

-- follow-up requests
create policy followup_select on public.followup_requests for select to authenticated
  using (user_id = auth.uid() or (public.is_reviewer() and status <> 'draft'));
create policy followup_insert_draft on public.followup_requests for insert to authenticated
  with check (user_id = auth.uid() and status = 'draft' and decision is null);
create policy followup_delete_draft on public.followup_requests for delete to authenticated
  using (user_id = auth.uid() and status = 'draft');
-- Column-level grants: no direct UPDATE; reviewers (and patients) never select
-- user_id through the API — RLS already scopes rows for patients.
revoke all on public.followup_requests from authenticated;
grant select (id, pseudo_ref, report_id, trigger_type, rule_ids, rules_version, reason, shared_snapshot, status, decision,
              provenance, created_at, updated_at) on public.followup_requests to authenticated;
grant insert (user_id, report_id, trigger_type, rule_ids, rules_version, reason, shared_snapshot, idempotency_key, provenance)
  on public.followup_requests to authenticated;
grant delete on public.followup_requests to authenticated;

create or replace function public.can_view_followup(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.followup_requests r
    where r.id = p_request_id
      and (r.user_id = auth.uid() or (public.is_reviewer() and r.status <> 'draft'))
  );
$$;

-- History, notes and integration events are written only by RPCs or the
-- backend; remove any default privileges before granting read access.
revoke all on public.followup_status_history, public.review_notes, public.integration_events from authenticated;

create policy history_select on public.followup_status_history for select to authenticated using (public.can_view_followup(request_id));
grant select on public.followup_status_history to authenticated;
create policy notes_select on public.review_notes for select to authenticated using (public.can_view_followup(request_id));
grant select (id, request_id, author_label, body, created_at) on public.review_notes to authenticated;
create policy events_select on public.integration_events for select to authenticated using (public.can_view_followup(request_id));
grant select (id, request_id, event_type, adapter, state, attempts, last_error, last_attempt_at, created_at)
  on public.integration_events to authenticated;

-- ----------------------------------------------------------------- RPCs

create or replace function public._followup_move(p_request_id uuid, p_from text[], p_to text, p_actor text, p_note text, p_decision text default null)
returns public.followup_requests
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests; v_from text;
begin
  select * into r from public.followup_requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if not (r.status = any (p_from)) then
    raise exception 'invalid_transition: % -> %', r.status, p_to using errcode = 'P0001';
  end if;
  v_from := r.status;
  update public.followup_requests
     set status = p_to, decision = coalesce(p_decision, decision), updated_at = now()
   where id = p_request_id
   returning * into r;
  insert into public.followup_status_history (request_id, from_status, to_status, actor_role, note)
  values (p_request_id, v_from, p_to, p_actor, p_note);
  return r;
end;
$$;
revoke all on function public._followup_move(uuid, text[], text, text, text, text) from public, anon, authenticated;

create or replace function public.submit_followup(p_request_id uuid, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests;
begin
  if not exists (select 1 from public.followup_requests where id = p_request_id and user_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  r := public._followup_move(p_request_id, array['draft', 'more_info_requested'], 'awaiting_review', 'patient', p_note);
  return r.status;
end;
$$;

create or replace function public.withdraw_followup(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests;
begin
  if not exists (select 1 from public.followup_requests where id = p_request_id and user_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  r := public._followup_move(p_request_id, array['draft', 'awaiting_review'], 'closed', 'patient', 'سحب المستخدم الطلب');
  return r.status;
end;
$$;

create or replace function public.reviewer_start_review(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests;
begin
  if not public.is_reviewer() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  r := public._followup_move(p_request_id, array['awaiting_review'], 'under_review', 'reviewer', null);
  return r.status;
end;
$$;

create or replace function public.reviewer_decide(p_request_id uuid, p_decision text, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests;
begin
  if not public.is_reviewer() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_decision not in ('review_required', 'data_completion', 'no_further_action_demo') then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  r := public._followup_move(
    p_request_id, array['under_review'],
    case when p_decision = 'data_completion' then 'more_info_requested' else 'reviewed' end,
    'reviewer', p_decision, p_decision);
  if p_note is not null and length(trim(p_note)) > 0 then
    insert into public.review_notes (request_id, author_id, body) values (p_request_id, auth.uid(), trim(p_note));
  end if;
  return r.status;
end;
$$;

create or replace function public.reviewer_add_note(p_request_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_reviewer() or not public.can_view_followup(p_request_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into public.review_notes (request_id, author_id, body) values (p_request_id, auth.uid(), trim(p_note));
end;
$$;

create or replace function public.close_followup(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r public.followup_requests; v_role text;
begin
  if public.is_reviewer() and public.can_view_followup(p_request_id) then
    v_role := 'reviewer';
  elsif exists (select 1 from public.followup_requests where id = p_request_id and user_id = auth.uid()) then
    v_role := 'patient';
  else
    raise exception 'forbidden' using errcode = '42501';
  end if;
  r := public._followup_move(p_request_id, array['reviewed'], 'closed', v_role, null);
  return r.status;
end;
$$;

-- Retention control: deletes every row the caller owns (the auth account
-- itself is removed separately by an admin or the auth API).
create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.followup_requests where user_id = uid;
  delete from public.visit_summaries where user_id = uid;
  delete from public.test_reminders where user_id = uid;
  delete from public.appointments where user_id = uid;
  delete from public.historical_comparisons where user_id = uid;
  delete from public.lab_results where user_id = uid;
  delete from public.device_reports where user_id = uid; -- cascades to fields, metrics, runs
  delete from public.consents where user_id = uid;
  delete from public.patient_identities where user_id = uid;
end;
$$;

-- Functions are executable by PUBLIC by default; lock everything down and
-- grant only the intended RPCs to signed-in users.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.is_reviewer() to authenticated;
grant execute on function public.can_view_followup(uuid) to authenticated;
grant execute on function public.submit_followup(uuid, text) to authenticated;
grant execute on function public.withdraw_followup(uuid) to authenticated;
grant execute on function public.reviewer_start_review(uuid) to authenticated;
grant execute on function public.reviewer_decide(uuid, text, text) to authenticated;
grant execute on function public.reviewer_add_note(uuid, text) to authenticated;
grant execute on function public.close_followup(uuid) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
