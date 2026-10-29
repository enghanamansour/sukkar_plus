-- 00 — Synthetic, pre-confirmed QA users (TEST PROJECTS ONLY). Password: Adeed-QA-2026!
create extension if not exists http with schema extensions;
do $$
declare u record;
begin
  for u in select * from (values
    ('11111111-aaaa-4aaa-8aaa-000000000001'::uuid, 'qa.patient.a@adeed-test.dev', 'QA Patient A'),
    ('22222222-bbbb-4bbb-8bbb-000000000002'::uuid, 'qa.patient.b@adeed-test.dev', 'QA Patient B')) as t(id, email, name)
  loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
      extensions.crypt('Adeed-QA-2026!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', u.name), now(), now(), '', '', '', '')
    on conflict (id) do nothing;
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), 'email', now(), now(), now())
    on conflict do nothing;
  end loop;
end $$;
