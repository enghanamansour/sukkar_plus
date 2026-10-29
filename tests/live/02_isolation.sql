-- 02 — Cross-user isolation: user A must not see or touch user B's data
create temp table qa_iso(step text, status int, body text);
do $do$
declare
  base text := 'https://bmoblgikggxaidntdakx.supabase.co';
  pk text := 'sb_publishable_5swnPU2A7DPNMhklYI-GEw_O1tiFkMY';  -- publishable key (browser-safe)
  r extensions.http_response; tok text; rid text; bpath text;
begin
  select id::text, file_path into rid, bpath from public.reports where user_id = '22222222-bbbb-4bbb-8bbb-000000000002' order by created_at desc limit 1;
  r := extensions.http(('POST', base||'/auth/v1/token?grant_type=password', array[extensions.http_header('apikey',pk)], 'application/json',
        '{"email":"qa.patient.a@adeed-test.dev","password":"Adeed-QA-2026!"}')::extensions.http_request);
  tok := (r.content::jsonb)->>'access_token';
  r := extensions.http(('GET', base||'/rest/v1/reports?select=id', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], null, null)::extensions.http_request);
  insert into qa_iso values ('A lists reports (expect [])', r.status, r.content);
  r := extensions.http(('GET', base||'/rest/v1/report_metrics?select=metric_key&report_id=eq.'||rid, array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], null, null)::extensions.http_request);
  insert into qa_iso values ('A reads B metrics (expect [])', r.status, r.content);
  r := extensions.http(('GET', base||'/rest/v1/doctor_questions?select=id', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], null, null)::extensions.http_request);
  insert into qa_iso values ('A reads questions (expect [])', r.status, r.content);
  r := extensions.http(('POST', base||'/functions/v1/process-report', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json', json_build_object('report_id', rid)::text)::extensions.http_request);
  insert into qa_iso values ('A processes B report (expect 404)', r.status, r.content);
  r := extensions.http(('GET', base||'/storage/v1/object/authenticated/reports/'||bpath, array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], null, null)::extensions.http_request);
  insert into qa_iso values ('A downloads B file (expect not found)', r.status, left(r.content,120));
  r := extensions.http(('GET', base||'/storage/v1/object/public/reports/'||bpath, array[extensions.http_header('apikey',pk)], null, null)::extensions.http_request);
  insert into qa_iso values ('public URL (expect bucket not found)', r.status, left(r.content,120));
  r := extensions.http(('POST', base||'/storage/v1/object/reports/22222222-bbbb-4bbb-8bbb-000000000002/evil.pdf', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/pdf', '%PDF-1.3 x')::extensions.http_request);
  insert into qa_iso values ('A writes into B folder (expect RLS denial)', r.status, left(r.content,160));
  r := extensions.http(('POST', base||'/rest/v1/reports', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json',
        '{"file_path":"22222222-bbbb-4bbb-8bbb-000000000002/x.pdf","file_name":"x.pdf","user_id":"22222222-bbbb-4bbb-8bbb-000000000002"}')::extensions.http_request);
  insert into qa_iso values ('A inserts report as B (expect 403)', r.status, left(r.content,160));
  r := extensions.http(('POST', base||'/rest/v1/reports', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json',
        '{"file_path":"11111111-aaaa-4aaa-8aaa-000000000001/x.pdf","file_name":"x.pdf","status":"processed","report_kind":"cgm_agp"}')::extensions.http_request);
  insert into qa_iso values ('A forges a processed report (expect 403)', r.status, left(r.content,160));
  r := extensions.http(('GET', base||'/rest/v1/reports?select=id', array[extensions.http_header('apikey',pk)], null, null)::extensions.http_request);
  insert into qa_iso values ('anonymous read (expect 401)', r.status, left(r.content,160));
end $do$;
select * from qa_iso;
