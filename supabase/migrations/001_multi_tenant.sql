-- Apex Scheduler — multi-tenant businesses model with RLS.
-- Replaces the incremental org/workspace migration with a full SaaS schema.

-- ---------------------------------------------------------------------------
-- Businesses (tenant root)
-- ---------------------------------------------------------------------------
create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry_type text not null default 'other'
    check (industry_type in ('restaurant', 'retail', 'fitness', 'healthcare', 'other')),
  owner_id uuid references auth.users(id) on delete set null,
  plan_tier text not null default 'free'
    check (plan_tier in ('free', 'pro')),
  created_at timestamptz not null default now()
);

-- Migrate legacy organizations row if present.
insert into businesses (id, name, industry_type, plan_tier, created_at)
select
  o.id,
  o.name,
  'restaurant',
  'pro',
  o.created_at
from organizations o
on conflict (id) do update
  set name = excluded.name;

-- Legacy seed org renamed to generic placeholder (Jigsy branding removed).
update businesses
  set name = 'Legacy Workspace', industry_type = 'other'
  where id = '00000000-0000-0000-0000-000000000001'
    and name ilike '%jigsy%';

-- ---------------------------------------------------------------------------
-- Profiles — business membership
-- ---------------------------------------------------------------------------
alter table profiles
  add column if not exists business_id uuid references businesses(id);

-- Backfill from organization_id when present.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'profiles' and column_name = 'organization_id'
  ) then
    update profiles p
    set business_id = p.organization_id
    where p.business_id is null and p.organization_id is not null;
  end if;
end $$;

update profiles
  set business_id = '00000000-0000-0000-0000-000000000001'
  where business_id is null;

alter table profiles alter column business_id drop default;
alter table profiles alter column business_id drop not null;

-- ---------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------
create table if not exists locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  address text,
  created_at timestamptz not null default now()
);

insert into locations (business_id, name, address)
select b.id, b.name || ' — Main', null
from businesses b
where not exists (
  select 1 from locations l where l.business_id = b.id
);

-- ---------------------------------------------------------------------------
-- Configurable roles per business
-- ---------------------------------------------------------------------------
create table if not exists roles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (business_id, name)
);

insert into roles (business_id, name, sort_order)
select b.id, r.name, r.ord
from businesses b
cross join (values
  ('General Staff', 0),
  ('Shift Lead', 1),
  ('Supervisor', 2)
) as r(name, ord)
on conflict (business_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- Staff invitations
-- ---------------------------------------------------------------------------
create table if not exists invitations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  invite_code text not null,
  created_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  max_uses int,
  use_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (invite_code)
);

create index if not exists invitations_business_id_idx on invitations (business_id);
create index if not exists invitations_invite_code_idx on invitations (invite_code);

-- ---------------------------------------------------------------------------
-- Tenant scope on operational tables
-- ---------------------------------------------------------------------------
alter table shifts add column if not exists business_id uuid references businesses(id);
alter table shifts add column if not exists location_id uuid references locations(id);

alter table availability add column if not exists business_id uuid references businesses(id);
alter table time_off_requests add column if not exists business_id uuid references businesses(id);
alter table time_entries add column if not exists business_id uuid references businesses(id);
alter table swaps add column if not exists business_id uuid references businesses(id);
alter table sidework add column if not exists business_id uuid references businesses(id);

-- Backfill operational rows to legacy business.
update shifts set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;
update availability set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;
update time_off_requests set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;
update time_entries set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;
update swaps set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;
update sidework set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

update shifts s
  set location_id = (
    select l.id from locations l
    where l.business_id = s.business_id
    order by l.created_at
    limit 1
  )
  where s.location_id is null and s.business_id is not null;

-- ---------------------------------------------------------------------------
-- Helper: current user's business_id (used by RLS)
-- ---------------------------------------------------------------------------
create or replace function public.current_user_business_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select business_id from profiles where id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table businesses enable row level security;
alter table profiles enable row level security;
alter table locations enable row level security;
alter table roles enable row level security;
alter table invitations enable row level security;
alter table shifts enable row level security;
alter table availability enable row level security;
alter table time_off_requests enable row level security;
alter table time_entries enable row level security;
alter table swaps enable row level security;
alter table sidework enable row level security;

-- Businesses
drop policy if exists businesses_select on businesses;
create policy businesses_select on businesses
  for select using (id = public.current_user_business_id() or owner_id = auth.uid());

drop policy if exists businesses_insert on businesses;
create policy businesses_insert on businesses
  for insert with check (owner_id = auth.uid());

drop policy if exists businesses_update on businesses;
create policy businesses_update on businesses
  for update using (owner_id = auth.uid());

-- Profiles
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles
  for select using (
    id = auth.uid()
    or business_id = public.current_user_business_id()
  );

drop policy if exists profiles_insert on profiles;
create policy profiles_insert on profiles
  for insert with check (id = auth.uid());

drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles
  for update using (
    id = auth.uid()
    or (
      business_id = public.current_user_business_id()
      and exists (
        select 1 from profiles p
        where p.id = auth.uid() and p.role = 'Owner'
      )
    )
  );

-- Locations
drop policy if exists locations_all on locations;
create policy locations_all on locations
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

-- Roles
drop policy if exists roles_all on roles;
create policy roles_all on roles
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

-- Invitations — owners manage; anyone can read by code for join flow
drop policy if exists invitations_select on invitations;
create policy invitations_select on invitations
  for select using (
    business_id = public.current_user_business_id()
    or true
  );

drop policy if exists invitations_insert on invitations;
create policy invitations_insert on invitations
  for insert with check (
    business_id = public.current_user_business_id()
    and exists (
      select 1 from profiles p where p.id = auth.uid() and p.role = 'Owner'
    )
  );

drop policy if exists invitations_update on invitations;
create policy invitations_update on invitations
  for update using (business_id = public.current_user_business_id());

drop policy if exists invitations_delete on invitations;
create policy invitations_delete on invitations
  for delete using (business_id = public.current_user_business_id());

-- Operational tables — scoped to business
drop policy if exists shifts_all on shifts;
create policy shifts_all on shifts
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

drop policy if exists availability_all on availability;
create policy availability_all on availability
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

drop policy if exists time_off_all on time_off_requests;
create policy time_off_all on time_off_requests
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

drop policy if exists time_entries_all on time_entries;
create policy time_entries_all on time_entries
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

drop policy if exists swaps_all on swaps;
create policy swaps_all on swaps
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());

drop policy if exists sidework_all on sidework;
create policy sidework_all on sidework
  for all using (business_id = public.current_user_business_id())
  with check (business_id = public.current_user_business_id());
