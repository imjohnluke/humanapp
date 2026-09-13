begin;
do $$
declare
  test_id uuid := gen_random_uuid();
  i integer;
begin
  if has_table_privilege('authenticated', 'public.pro_entitlements', 'INSERT')
     or has_table_privilege('authenticated', 'public.pro_entitlements', 'UPDATE')
     or has_table_privilege('anon', 'public.pro_entitlements', 'SELECT')
     or has_function_privilege('authenticated', 'public.reserve_photo_estimate(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.reserve_photo_estimate(uuid)', 'EXECUTE') then
    raise exception 'Client privileges are too broad';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'public.pro_entitlements'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.photo_estimate_usage'::regclass) then
    raise exception 'RLS missing';
  end if;
  insert into auth.users (id) values (test_id);
  if public.reserve_photo_estimate(test_id) then raise exception 'Non-Pro user accepted'; end if;
  insert into public.pro_entitlements (user_id, expires_at) values (test_id, now() - interval '1 day');
  if public.reserve_photo_estimate(test_id) then raise exception 'Expired user accepted'; end if;
  update public.pro_entitlements set expires_at = now() + interval '1 day' where user_id = test_id;
  for i in 1..20 loop
    if not public.reserve_photo_estimate(test_id) then raise exception 'Valid quota denied at %', i; end if;
  end loop;
  if public.reserve_photo_estimate(test_id) then raise exception 'Quota exceeded'; end if;
  if (select attempts from public.photo_estimate_usage where user_id = test_id) <> 20 then raise exception 'Incorrect usage count'; end if;
end;
$$;
select 'PASS: Pro expiry, 20-attempt quota, client privileges, RLS' as result;
rollback;
