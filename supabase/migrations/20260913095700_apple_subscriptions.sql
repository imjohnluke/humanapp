create table public.apple_sandbox_testers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz not null
);
alter table public.apple_sandbox_testers enable row level security;
revoke all on public.apple_sandbox_testers from public, anon, authenticated;
grant all on public.apple_sandbox_testers to service_role;
create policy "Service manages sandbox testers" on public.apple_sandbox_testers to service_role using (true) with check (true);

create table public.apple_subscriptions (
  original_transaction_id text not null,
  environment text not null check (environment in ('Production', 'Sandbox')),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null check (product_id in ('com.humanhydration.pro.monthly', 'com.humanhydration.pro.yearly')),
  expires_at timestamptz not null,
  signed_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (original_transaction_id, environment)
);
create index apple_subscriptions_user_idx on public.apple_subscriptions(user_id);
alter table public.apple_subscriptions enable row level security;
revoke all on public.apple_subscriptions from public, anon, authenticated;
grant all on public.apple_subscriptions to service_role;
create policy "Service manages verified subscriptions" on public.apple_subscriptions to service_role using (true) with check (true);

-- Manual/internal Pro grants stay independent from Apple purchases and refunds.
create view public.pro_access with (security_invoker = true) as
select user_id, max(expires_at) as expires_at from (
  select user_id, expires_at from public.pro_entitlements
  union all
  select s.user_id, s.expires_at from public.apple_subscriptions s
  where s.environment = 'Production' or exists (
    select 1 from public.apple_sandbox_testers t where t.user_id = s.user_id and t.expires_at > now()
  )
) grants group by user_id;
revoke all on public.pro_access from public, anon, authenticated;
grant select on public.pro_access to service_role;

create function public.record_apple_subscription(
  p_original_id text, p_environment text, p_user_id uuid, p_product_id text,
  p_expires_at timestamptz, p_signed_at timestamptz
) returns boolean language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.apple_subscriptions(original_transaction_id, environment, user_id, product_id, expires_at, signed_at)
  values (p_original_id, p_environment, p_user_id, p_product_id, p_expires_at, p_signed_at)
  on conflict (original_transaction_id, environment) do update
    set product_id = excluded.product_id, expires_at = excluded.expires_at,
        signed_at = excluded.signed_at, updated_at = now()
    where public.apple_subscriptions.user_id = excluded.user_id
      and public.apple_subscriptions.signed_at <= excluded.signed_at;
  if exists (select 1 from public.apple_subscriptions where original_transaction_id = p_original_id
    and environment = p_environment and user_id <> p_user_id) then
    raise exception 'Subscription belongs to another account';
  end if;
  return true;
end;
$$;
revoke all on function public.record_apple_subscription(text,text,uuid,text,timestamptz,timestamptz) from public, anon, authenticated;
grant execute on function public.record_apple_subscription(text,text,uuid,text,timestamptz,timestamptz) to service_role;

create or replace function public.reserve_photo_estimate(p_user_id uuid)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare reserved integer;
begin
  if not exists (select 1 from public.pro_access where user_id = p_user_id and expires_at > now()) then return false; end if;
  insert into public.photo_estimate_usage(user_id, usage_day, attempts)
    values (p_user_id, (now() at time zone 'UTC')::date, 1)
  on conflict (user_id, usage_day) do update set attempts = public.photo_estimate_usage.attempts + 1
    where public.photo_estimate_usage.attempts < 20
  returning attempts into reserved;
  return reserved is not null;
end;
$$;
