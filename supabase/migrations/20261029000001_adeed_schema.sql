-- Adeed (عضيد) — core schema, RLS and private storage.
-- Idempotent-ish: uses IF NOT EXISTS where Postgres allows it. Non-destructive.

create extension if not exists pgcrypto;

-- ───────────────────────── profiles ─────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (char_length(full_name) <= 120),
  preferred_language text not null default 'ar' check (preferred_language in ('ar', 'en')),
  diabetes_type text not null default 'unknown'
    check (diabetes_type in ('type1', 'type2', 'gestational', 'other', 'unknown')),
  next_appointment_at timestamptz,
  clinic_name text check (char_length(clinic_name) <= 160),
  appointment_notes text check (char_length(appointment_notes) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 120))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ───────────────────────── reports ─────────────────────────
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text check (char_length(title) <= 200),
  file_path text not null,
  file_name text not null check (char_length(file_name) <= 255),
  file_size integer check (file_size is null or file_size between 1 and 10485760),
  status text not null default 'uploaded'
    check (status in ('uploaded', 'processing', 'processed', 'failed')),
  error_code text,
  error_message text,
  report_kind text not null default 'unknown' check (report_kind in ('cgm_agp', 'lab', 'unknown')),
  source_system text,
  device text,
  period_start date,
  period_end date,
  period_days integer,
  generated_on date,
  name_on_report text,
  page_count integer,
  quality jsonb not null default '{}'::jsonb,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint reports_path_owner check (split_part(file_path, '/', 1) = user_id::text),
  constraint reports_period_order check (period_start is null or period_end is null or period_start <= period_end)
);
create index if not exists reports_user_idx on public.reports (user_id, period_end desc nulls last);

-- ───────────────────────── report_metrics ─────────────────────────
create table if not exists public.report_metrics (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  metric_key text not null,
  category text not null check (category in ('glycemic', 'range', 'variability', 'usage', 'device_setting', 'lab')),
  value numeric,
  value_text text,
  unit text,
  status text not null check (status in ('extracted', 'calculated', 'unavailable', 'uncertain')),
  source_page integer,
  source_label text,
  note text,
  created_at timestamptz not null default now(),
  unique (report_id, metric_key)
);
create index if not exists report_metrics_user_idx on public.report_metrics (user_id, metric_key);
create index if not exists report_metrics_report_idx on public.report_metrics (report_id);

-- ───────────────────────── lab_results (HbA1c is kept separate from GMI) ─────────────────────────
create table if not exists public.lab_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  test_key text not null default 'hba1c' check (test_key in ('hba1c')),
  value numeric not null check (value >= 3 and value <= 20),
  unit text not null default '%' check (unit = '%'),
  measured_on date not null check (measured_on <= current_date + 1),
  source text not null default 'manual' check (source in ('manual', 'demo', 'report')),
  report_id uuid references public.reports (id) on delete set null,
  note text check (char_length(note) <= 500),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists lab_results_user_idx on public.lab_results (user_id, measured_on desc);

-- ───────────────────────── doctor_questions ─────────────────────────
create table if not exists public.doctor_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  report_id uuid references public.reports (id) on delete cascade,
  rule_key text,
  question text not null check (char_length(question) between 3 and 1000),
  rationale text check (char_length(rationale) <= 2000),
  evidence jsonb not null default '[]'::jsonb,
  basis text not null default 'finding' check (basis in ('finding', 'comparison', 'data_gap', 'custom')),
  is_uncertain boolean not null default false,
  is_saved boolean not null default false,
  is_edited boolean not null default false,
  generated_by text not null default 'user' check (generated_by in ('rules', 'assistant', 'user')),
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists doctor_questions_user_idx on public.doctor_questions (user_id, report_id, position);

drop trigger if exists doctor_questions_touch on public.doctor_questions;
create trigger doctor_questions_touch before update on public.doctor_questions
  for each row execute function public.touch_updated_at();

-- ───────────────────────── chat_messages (one persistent thread per user) ─────────────────────────
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) <= 12000),
  tool_trace jsonb not null default '[]'::jsonb,
  flags jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_user_idx on public.chat_messages (user_id, created_at);

-- ───────────────────────── Row Level Security ─────────────────────────
alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.report_metrics enable row level security;
alter table public.lab_results enable row level security;
alter table public.doctor_questions enable row level security;
alter table public.chat_messages enable row level security;

-- profiles: own row only; no insert (trigger does it), no delete (cascade from auth.users)
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated
  using (id = (select auth.uid()));
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- reports: users create their own 'uploaded' rows, read and delete them. Processing results are
-- written only by the server (service role), so extracted values cannot be edited from the browser.
drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'uploaded'
    and report_kind = 'unknown'
    and split_part(file_path, '/', 1) = (select auth.uid())::text
  );
drop policy if exists reports_delete_own on public.reports;
create policy reports_delete_own on public.reports for delete to authenticated
  using (user_id = (select auth.uid()));

-- report_metrics: read-only for the owner
drop policy if exists report_metrics_select_own on public.report_metrics;
create policy report_metrics_select_own on public.report_metrics for select to authenticated
  using (user_id = (select auth.uid()));

-- lab_results: owner full control (manual HbA1c entries)
drop policy if exists lab_results_select_own on public.lab_results;
create policy lab_results_select_own on public.lab_results for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists lab_results_insert_own on public.lab_results;
create policy lab_results_insert_own on public.lab_results for insert to authenticated
  with check (user_id = (select auth.uid()) and source in ('manual', 'demo'));
drop policy if exists lab_results_update_own on public.lab_results;
create policy lab_results_update_own on public.lab_results for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and source in ('manual', 'demo'));
drop policy if exists lab_results_delete_own on public.lab_results;
create policy lab_results_delete_own on public.lab_results for delete to authenticated
  using (user_id = (select auth.uid()));

-- doctor_questions: owner reads, edits, deletes; may add custom questions
drop policy if exists doctor_questions_select_own on public.doctor_questions;
create policy doctor_questions_select_own on public.doctor_questions for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists doctor_questions_insert_own on public.doctor_questions;
create policy doctor_questions_insert_own on public.doctor_questions for insert to authenticated
  with check (user_id = (select auth.uid()) and generated_by = 'user' and basis = 'custom'
    and (report_id is null or exists (select 1 from public.reports r where r.id = report_id and r.user_id = (select auth.uid()))));
drop policy if exists doctor_questions_update_own on public.doctor_questions;
create policy doctor_questions_update_own on public.doctor_questions for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists doctor_questions_delete_own on public.doctor_questions;
create policy doctor_questions_delete_own on public.doctor_questions for delete to authenticated
  using (user_id = (select auth.uid()));

-- chat_messages: owner reads and may clear history; messages are written by the chat function
drop policy if exists chat_messages_select_own on public.chat_messages;
create policy chat_messages_select_own on public.chat_messages for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists chat_messages_delete_own on public.chat_messages;
create policy chat_messages_delete_own on public.chat_messages for delete to authenticated
  using (user_id = (select auth.uid()));

-- Tighten default grants: anon gets nothing on these tables.
revoke all on public.profiles, public.reports, public.report_metrics, public.lab_results,
  public.doctor_questions, public.chat_messages from anon;

-- ───────────────────────── Private storage for uploaded PDFs ─────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('reports', 'reports', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = 10485760, allowed_mime_types = array['application/pdf'];

drop policy if exists "reports: owner can upload" on storage.objects;
create policy "reports: owner can upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'reports' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "reports: owner can read" on storage.objects;
create policy "reports: owner can read" on storage.objects for select to authenticated
  using (bucket_id = 'reports' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "reports: owner can delete" on storage.objects;
create policy "reports: owner can delete" on storage.objects for delete to authenticated
  using (bucket_id = 'reports' and (storage.foldername(name))[1] = (select auth.uid())::text);
