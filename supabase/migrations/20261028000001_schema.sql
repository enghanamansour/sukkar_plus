-- Sukkar Plus — schema
-- Independent concept prototype. Not connected to Sehhaty or any provider.
-- Personally identifying data (display name) lives in patient_identities,
-- separate from analytic tables, which reference the user only by UUID.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  pseudo_id text not null unique
    default ('SP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))),
  role text not null default 'patient' check (role in ('patient', 'reviewer')),
  target_profile text not null default 'unspecified'
    check (target_profile in ('general_adult_t1_t2', 'older_or_high_risk', 'pregnancy', 'pediatric', 'unspecified')),
  created_at timestamptz not null default now()
);
comment on column public.profiles.role is 'Changed only by an administrator (service role). Users cannot update it.';

create table public.patient_identities (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  version text not null,
  allows_external_ai boolean not null default false,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index consents_user_idx on public.consents (user_id);

create table public.device_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  provenance text not null check (provenance in ('real', 'synthetic')),
  source_type text not null check (source_type in ('pdf_upload', 'demo_fixture', 'readings_import')),
  format_id text,
  device_label text,
  file_sha256 text,
  file_size_bytes integer check (file_size_bytes is null or file_size_bytes >= 0),
  page_count integer,
  -- null unless secure storage is explicitly configured; PDFs are not kept by default.
  storage_path text,
  report_period_start date,
  report_period_end date,
  metrics_period_start date,
  metrics_period_end date,
  status text not null default 'pending_review' check (status in ('pending_review', 'accepted', 'rejected')),
  -- deterministic data-sufficiency summary and parser warnings (no raw text)
  data_quality jsonb,
  warnings jsonb not null default '[]',
  created_at timestamptz not null default now(),
  check (report_period_end is null or report_period_start is null or report_period_end >= report_period_start),
  check (metrics_period_end is null or metrics_period_start is null or metrics_period_end >= metrics_period_start)
);
create index device_reports_user_idx on public.device_reports (user_id);

create table public.extracted_fields (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.device_reports (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  metric_key text not null,
  extracted_value numeric,
  corrected_value numeric,
  ai_value numeric,
  unit text not null,
  source_page integer,
  source_label text,
  extraction_status text not null check (extraction_status in ('found', 'not_found', 'ambiguous')),
  validation_status text not null check (validation_status in ('valid', 'out_of_range', 'inconsistent', 'not_cross_checked')),
  method text not null check (method in ('local_text', 'ai', 'local_and_ai_agree', 'local_and_ai_disagree')),
  marked_unavailable boolean not null default false,
  confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  unique (report_id, metric_key)
);

create table public.analysis_runs (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.device_reports (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rules_version text not null,
  target_profile text not null,
  outcome text not null check (outcome in ('routine_summary', 'review_suggested', 'need_more_data', 'seek_medical_help')),
  data_quality jsonb not null,
  rule_results jsonb not null,
  created_at timestamptz not null default now()
);

create table public.verified_metrics (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.device_reports (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  metric_key text not null,
  value numeric,
  unit text not null,
  origin text not null check (origin in ('extracted_from_report', 'calculated_from_readings', 'calculated_from_metrics', 'user_corrected', 'user_entered')),
  verification_status text not null check (verification_status in ('verified', 'needs_review', 'unavailable', 'rejected')),
  original_extracted_value numeric,
  source_page integer,
  source_label text,
  created_at timestamptz not null default now(),
  unique (report_id, metric_key),
  -- missing values are stored as null with status 'unavailable', never as 0
  check (value is not null or verification_status in ('unavailable', 'rejected'))
);

create table public.lab_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  test_code text not null check (test_code in ('hba1c', 'fasting_plasma_glucose', 'creatinine', 'egfr', 'ldl', 'uacr', 'other')),
  test_name text not null,
  value numeric not null,
  unit text not null,
  collection_date date,
  ref_low numeric,
  ref_high numeric,
  ref_text text,
  source text not null check (source in ('manual', 'extracted', 'future_integration')),
  lab_name text,
  verification_status text not null check (verification_status in ('verified', 'needs_review', 'unavailable', 'rejected')),
  provenance text not null check (provenance in ('real', 'synthetic')),
  created_at timestamptz not null default now(),
  check (ref_low is null or ref_high is null or ref_low <= ref_high),
  check (test_code <> 'hba1c' or unit in ('%', 'mmol/mol'))
);
create index lab_results_user_idx on public.lab_results (user_id, test_code, collection_date);

create table public.historical_comparisons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('gmi_hba1c', 'cgm_periods', 'lab_trend')),
  subject_ids uuid[] not null,
  method_version text not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  scheduled_at timestamptz not null,
  clinic_label text not null,
  -- the prototype never stores real bookings
  is_simulated boolean not null default true check (is_simulated),
  provenance text not null check (provenance in ('real', 'synthetic')),
  created_at timestamptz not null default now()
);

create table public.test_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  test_code text not null,
  test_name text not null,
  due_date date not null,
  remind_at timestamptz,
  appointment_id uuid references public.appointments (id) on delete set null,
  schedule_source text not null check (schedule_source in ('clinician_provided', 'user_confirmed')),
  status text not null default 'scheduled' check (status in ('scheduled', 'completed', 'cancelled')),
  completed_at timestamptz,
  collection_date date,
  result_id uuid references public.lab_results (id) on delete set null,
  note text,
  history jsonb not null default '[]',
  provenance text not null check (provenance in ('real', 'synthetic')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index test_reminders_user_idx on public.test_reminders (user_id, due_date);

create table public.visit_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  appointment_id uuid references public.appointments (id) on delete set null,
  generated_at timestamptz not null default now(),
  content jsonb not null
);

create table public.followup_requests (
  id uuid primary key default gen_random_uuid(),
  pseudo_ref text not null unique
    default ('REQ-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))),
  user_id uuid not null references public.profiles (id) on delete cascade,
  report_id uuid references public.device_reports (id) on delete set null,
  trigger_type text not null check (trigger_type in ('rule', 'user_request')),
  rule_ids text[] not null default '{}',
  rules_version text not null,
  reason text not null,
  -- exactly what the patient reviewed and agreed to share with the reviewer
  shared_snapshot jsonb not null,
  status text not null default 'draft'
    check (status in ('draft', 'awaiting_review', 'under_review', 'more_info_requested', 'reviewed', 'closed')),
  decision text check (decision in ('review_required', 'data_completion', 'no_further_action_demo')),
  idempotency_key text not null,
  provenance text not null check (provenance in ('real', 'synthetic')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- duplicate prevention: one open request per idempotency key
create unique index followup_requests_open_idem on public.followup_requests (idempotency_key) where status <> 'closed';
create index followup_requests_status_idx on public.followup_requests (status, updated_at desc);

create table public.followup_status_history (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.followup_requests (id) on delete cascade,
  from_status text,
  to_status text not null,
  actor_role text not null check (actor_role in ('patient', 'reviewer', 'system')),
  note text,
  created_at timestamptz not null default now()
);

create table public.review_notes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.followup_requests (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  author_label text not null default 'مراجع تجريبي (ليس طبيبًا حقيقيًا)',
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create table public.integration_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.followup_requests (id) on delete cascade,
  event_type text not null,
  idempotency_key text not null unique,
  adapter text not null check (adapter in ('make_webhook', 'local_mock')),
  state text not null check (state in ('pending', 'mock_recorded', 'sent', 'failed')),
  attempts integer not null default 0,
  last_error text,
  last_attempt_at timestamptz,
  -- the exact minimal payload sent (no names, IDs, values or report content)
  payload jsonb not null,
  created_at timestamptz not null default now()
);

-- New auth users get a patient profile. Roles are changed by an admin only.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
