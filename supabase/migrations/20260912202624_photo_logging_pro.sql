-- Written only by trusted billing/admin services, never by an app client.
create table public.pro_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
alter table public.pro_entitlements enable row level security;
revoke all on public.pro_entitlements from public, anon, authenticated;
grant select on public.pro_entitlements to authenticated;
grant all on public.pro_entitlements to service_role;
create policy "Users can read their Pro access" on public.pro_entitlements
  for select to authenticated using ((select auth.uid()) = user_id);

-- Only aggregate usage is retained. No photos or model responses are saved.
create table public.photo_estimate_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_day date not null,
  attempts integer not null check (attempts between 1 and 20),
  primary key (user_id, usage_day)
);
alter table public.photo_estimate_usage enable row level security;
revoke all on public.photo_estimate_usage from public, anon, authenticated;
grant all on public.photo_estimate_usage to service_role;

-- Atomic limit across concurrent Edge Function instances. Service-role only.
create function public.reserve_photo_estimate(p_user_id uuid)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare reserved integer;
begin
  if not exists (select 1 from public.pro_entitlements
    where user_id = p_user_id and expires_at > now()) then
    return false;
  end if;
  insert into public.photo_estimate_usage (user_id, usage_day, attempts)
    values (p_user_id, (now() at time zone 'UTC')::date, 1)
  on conflict (user_id, usage_day) do update
    set attempts = public.photo_estimate_usage.attempts + 1
    where public.photo_estimate_usage.attempts < 20
  returning attempts into reserved;
  return reserved is not null;
end;
$$;
revoke all on function public.reserve_photo_estimate(uuid) from public, anon, authenticated;
grant execute on function public.reserve_photo_estimate(uuid) to service_role;
