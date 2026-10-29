-- 99 — Remove QA users (their rows cascade) and their files, then drop the http extension.
delete from storage.objects where bucket_id = 'reports' and (storage.foldername(name))[1] in
  ('11111111-aaaa-4aaa-8aaa-000000000001', '22222222-bbbb-4bbb-8bbb-000000000002');
delete from auth.users where id in ('11111111-aaaa-4aaa-8aaa-000000000001', '22222222-bbbb-4bbb-8bbb-000000000002');
drop extension if exists http;
