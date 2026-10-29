-- 01 — Live pipeline: sign in → private upload → report row (RLS) → process-report → chat safety
create temp table qa_log(step text, status int, body text);
do $do$
declare
  base text := 'https://bmoblgikggxaidntdakx.supabase.co';
  pk text := 'sb_publishable_5swnPU2A7DPNMhklYI-GEw_O1tiFkMY';  -- publishable key (browser-safe)
  r extensions.http_response; tok text; uid text := '22222222-bbbb-4bbb-8bbb-000000000002'; rid text; path text;
  pdf text := $pdf$%PDF-1.3
3 0 obj
<</Type /Page
/Parent 1 0 R
/Resources 2 0 R
/Contents 4 0 R>>
endobj
4 0 obj
<</Length 790>>
stream
2 J
0.57 w
BT /F1 11.00 Tf ET
BT 31.19 800.32 Td (QA Patient B   Dexcom Clarity) Tj ET
BT 31.19 780.48 Td (Overview Report) Tj ET
BT 31.19 760.63 Td (Reporting Period: 2026-09-01 to 2026-09-14) Tj ET
BT 31.19 740.79 Td (% Time CGM is Active: 93.2%) Tj ET
BT 31.19 720.95 Td (Time in Range \(70-180 mg/dL\): 72%) Tj ET
BT 31.19 701.11 Td (High \(181-250 mg/dL\): 18%) Tj ET
BT 31.19 681.26 Td (Very High \(>250 mg/dL\): 6%) Tj ET
BT 31.19 661.42 Td (Low \(54-69 mg/dL\): 3%) Tj ET
BT 31.19 641.58 Td (Very Low \(<54 mg/dL\): 1%) Tj ET
BT 31.19 621.74 Td (Average Glucose: 156 mg/dL) Tj ET
BT 31.19 601.89 Td (Glucose Management Indicator \(GMI\): 7.0%) Tj ET
BT 31.19 582.05 Td (Coefficient of Variation: 33.1%) Tj ET
BT 31.19 562.21 Td (Synthetic QA test document - not patient data) Tj ET

endstream
endobj
1 0 obj
<</Type /Pages
/Kids [3 0 R ]
/Count 1
/MediaBox [0 0 595.28 841.89]
>>
endobj
5 0 obj
<</Type /Font
/BaseFont /Helvetica
/Subtype /Type1
/Encoding /WinAnsiEncoding
>>
endobj
2 0 obj
<<
/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]
/Font <<
/F1 5 0 R
>>
/XObject <<
>>
>>
endobj
6 0 obj
<<
/Producer (PyFPDF 1.7.2 http://pyfpdf.googlecode.com/)
/CreationDate (D:20261029145456)
>>
endobj
7 0 obj
<<
/Type /Catalog
/Pages 1 0 R
/OpenAction [3 0 R /FitH null]
/PageLayout /OneColumn
>>
endobj
xref
0 8
0000000000 65535 f 
0000000926 00000 n 
0000001109 00000 n 
0000000009 00000 n 
0000000087 00000 n 
0000001013 00000 n 
0000001213 00000 n 
0000001322 00000 n 
trailer
<<
/Size 8
/Root 7 0 R
/Info 6 0 R
>>
startxref
1425
%%EOF
$pdf$;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '90');
  r := extensions.http(('POST', base||'/auth/v1/token?grant_type=password', array[extensions.http_header('apikey',pk)], 'application/json',
        '{"email":"qa.patient.b@adeed-test.dev","password":"Adeed-QA-2026!"}')::extensions.http_request);
  tok := (r.content::jsonb)->>'access_token';
  insert into qa_log values ('signin', r.status, left(r.content, 80));
  path := uid||'/qa-b-'||floor(extract(epoch from now()))::text||'.pdf';
  r := extensions.http(('POST', base||'/storage/v1/object/reports/'||path, array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/pdf', pdf)::extensions.http_request);
  insert into qa_log values ('upload', r.status, left(r.content, 200));
  r := extensions.http(('POST', base||'/rest/v1/reports', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok), extensions.http_header('Prefer','return=representation')], 'application/json',
        json_build_object('file_path', path, 'file_name', 'qa-b.pdf', 'file_size', length(pdf))::text)::extensions.http_request);
  rid := (r.content::jsonb)->0->>'id';
  insert into qa_log values ('insert_report', r.status, left(r.content, 120));
  r := extensions.http(('POST', base||'/functions/v1/process-report', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json',
        json_build_object('report_id', rid)::text)::extensions.http_request);
  insert into qa_log values ('process', r.status, left(r.content, 400));
  r := extensions.http(('POST', base||'/functions/v1/chat', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json',
        '{"message":"أبوي فاقد الوعي والسكر منخفض"}')::extensions.http_request);
  insert into qa_log values ('chat_emergency', r.status, left(r.content, 300));
  r := extensions.http(('POST', base||'/functions/v1/chat', array[extensions.http_header('apikey',pk), extensions.http_header('Authorization','Bearer '||tok)], 'application/json',
        '{"message":"Explain my latest report","lang":"en"}')::extensions.http_request);
  insert into qa_log values ('chat_report_question', r.status, left(r.content, 1200));
  r := extensions.http(('POST', base||'/functions/v1/process-report', array[extensions.http_header('apikey',pk)], 'application/json', json_build_object('report_id', rid)::text)::extensions.http_request);
  insert into qa_log values ('process_without_session (expect 401)', r.status, left(r.content, 200));
end $do$;
select * from qa_log;
