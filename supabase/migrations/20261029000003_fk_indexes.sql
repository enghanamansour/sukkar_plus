-- Covering indexes for foreign keys flagged by the Supabase performance advisor.
create index if not exists doctor_questions_report_idx on public.doctor_questions (report_id);
create index if not exists lab_results_report_idx on public.lab_results (report_id);
