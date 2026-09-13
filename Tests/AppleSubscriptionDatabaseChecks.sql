begin;
do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  original text := gen_random_uuid()::text;
  sandbox_original text := gen_random_uuid()::text;
  denied boolean := false;
  granted timestamptz;
begin
  insert into auth.users(id) values (a), (b);
  if has_table_privilege('authenticated','public.apple_subscriptions','INSERT') or
     has_table_privilege('authenticated','public.apple_sandbox_testers','INSERT') or
     has_function_privilege('authenticated','public.record_apple_subscription(text,text,uuid,text,timestamptz,timestamptz)','EXECUTE') then
    raise exception 'Client can grant paid access';
  end if;
  perform public.record_apple_subscription(original,'Production',a,'com.humanhydration.pro.monthly',now()+interval '1 month',now());
  if not exists(select 1 from public.pro_access where user_id=a and expires_at>now()) then raise exception 'Purchase missing'; end if;
  begin
    perform public.record_apple_subscription(original,'Production',b,'com.humanhydration.pro.monthly',now()+interval '1 month',now());
  exception when others then denied := true;
  end;
  if not denied then raise exception 'Purchase reassigned to another user'; end if;
  perform public.record_apple_subscription(original,'Production',a,'com.humanhydration.pro.monthly','1970-01-01',now()+interval '1 second');
  perform public.record_apple_subscription(original,'Production',a,'com.humanhydration.pro.monthly',now()+interval '1 month',now());
  if exists(select 1 from public.pro_access where user_id=a and expires_at>now()) then raise exception 'Old event reversed refund'; end if;
  insert into public.pro_entitlements(user_id,expires_at) values(a,now()+interval '90 days');
  if not exists(select 1 from public.pro_access where user_id=a and expires_at>now()) then raise exception 'Refund removed manual grant'; end if;
  perform public.record_apple_subscription(sandbox_original,'Sandbox',b,'com.humanhydration.pro.yearly',now()+interval '1 year',now());
  if exists(select 1 from public.pro_access where user_id=b and expires_at>now()) then raise exception 'Unapproved sandbox access'; end if;
  insert into public.apple_sandbox_testers(user_id,expires_at) values(b,now()+interval '1 day');
  if not exists(select 1 from public.pro_access where user_id=b and expires_at>now()) then raise exception 'Approved sandbox not active'; end if;
  update public.apple_sandbox_testers set expires_at=now()-interval '1 day' where user_id=b;
  if exists(select 1 from public.pro_access where user_id=b and expires_at>now()) then raise exception 'Expired tester active'; end if;
end;
$$;
select 'PASS: purchase access, account binding, refund ordering, manual grant preservation, sandbox isolation' as result;
rollback;
