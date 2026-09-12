create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  daily_goal_ml integer not null default 2400 check (daily_goal_ml between 500 and 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.bottles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  asset_name text not null,
  color_name text not null default 'blue',
  capacity_ml integer not null check (capacity_ml between 50 and 7570),
  created_at timestamptz not null default now()
);

create table public.hydration_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bottle_id uuid references public.bottles(id) on delete set null,
  amount_ml integer not null check (amount_ml between 10 and 7570),
  logged_at timestamptz not null default now()
);

create index hydration_entries_user_logged_at_idx on public.hydration_entries(user_id, logged_at desc);
create index bottles_user_id_idx on public.bottles(user_id);

alter table public.profiles enable row level security;
alter table public.bottles enable row level security;
alter table public.hydration_entries enable row level security;

create policy "Users can view their profile" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "Users can create their profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "Users can update their profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Users can view their bottles" on public.bottles for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can create their bottles" on public.bottles for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their bottles" on public.bottles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their bottles" on public.bottles for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can view their hydration" on public.hydration_entries for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can log hydration" on public.hydration_entries for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their hydration" on public.hydration_entries for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their hydration" on public.hydration_entries for delete to authenticated using ((select auth.uid()) = user_id);
