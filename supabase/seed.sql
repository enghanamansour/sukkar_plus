-- Sukkar Plus — SYNTHETIC demo seed for a real Supabase project (optional).
-- Every value here is invented. Run AFTER creating two users in
-- Authentication → Users (or via sign-up in the app):
--   demo-patient@example.com   and   demo-reviewer@example.com
-- Then run this file in the SQL editor (it runs as the postgres role).
-- The app's built-in demo mode does NOT need this file.

do $$
declare
  p uuid := (select id from auth.users where email = 'demo-patient@example.com');
  r uuid := (select id from auth.users where email = 'demo-reviewer@example.com');
  rep uuid;
  req uuid;
begin
  if p is null or r is null then
    raise exception 'Create demo-patient@example.com and demo-reviewer@example.com first.';
  end if;

  -- Role assignment is an administrator action (users cannot change roles).
  update public.profiles set role = 'reviewer' where id = r;
  update public.profiles set target_profile = 'general_adult_t1_t2' where id = p;
  insert into public.patient_identities (user_id, display_name) values (p, 'سارة (اسم تجريبي)')
    on conflict (user_id) do nothing;

  insert into public.device_reports (user_id, provenance, source_type, format_id, device_label,
      report_period_start, report_period_end, metrics_period_start, metrics_period_end, status)
  values (p, 'synthetic', 'demo_fixture', 'omnipod_discover_agp_summary_v1', 'Omnipod 5 & Dexcom G7 (synthetic)',
      current_date - 104, current_date - 91, current_date - 104, current_date - 91, 'accepted')
  returning id into rep;

  insert into public.verified_metrics (report_id, user_id, metric_key, value, unit, origin, verification_status) values
    (rep, p, 'mean_glucose', 172, 'mg/dL', 'extracted_from_report', 'verified'),
    (rep, p, 'gmi', 7.4, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'cv', 38.2, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'time_very_low', 0.6, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'time_low', 2.4, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'time_in_range', 62, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'time_high', 27, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'time_very_high', 8, '%', 'extracted_from_report', 'verified'),
    (rep, p, 'sensor_active', 91, '%', 'extracted_from_report', 'verified');

  insert into public.lab_results (user_id, test_code, test_name, value, unit, collection_date, source, verification_status, provenance, lab_name) values
    (p, 'hba1c', 'HbA1c', 7.6, '%', current_date - 88, 'manual', 'verified', 'synthetic', 'مختبر تجريبي'),
    (p, 'hba1c', 'HbA1c', 54, 'mmol/mol', current_date - 45, 'manual', 'verified', 'synthetic', 'مختبر تجريبي');

  insert into public.appointments (user_id, scheduled_at, clinic_label, provenance)
  values (p, (current_date + 12) + time '10:30', 'عيادة السكري — موعد محاكى (ليس حجزًا حقيقيًا)', 'synthetic');

  insert into public.test_reminders (user_id, test_code, test_name, due_date, schedule_source, provenance, note)
  values (p, 'hba1c', 'السكر التراكمي (HbA1c)', current_date + 6, 'clinician_provided', 'synthetic', 'جدول تجريبي');

  insert into public.followup_requests (user_id, report_id, trigger_type, rule_ids, rules_version, reason, shared_snapshot,
      status, idempotency_key, provenance)
  values (p, rep, 'rule', '{TAR250-TARGET}', '2026.10-demo.1',
      'مرتفع جدًا (أعلى من 250) 8% لا يستوفي الهدف المرجعي العام (أقل من 5%).',
      '{"period": "synthetic", "items": {"مرتفع جدًا (أعلى من 250)": "8%"}}', 'awaiting_review',
      p::text || '|' || rep::text || '|rule|TAR250-TARGET', 'synthetic')
  returning id into req;
  insert into public.followup_status_history (request_id, from_status, to_status, actor_role, note)
  values (req, 'draft', 'awaiting_review', 'patient', 'بيانات تجريبية');
end $$;
