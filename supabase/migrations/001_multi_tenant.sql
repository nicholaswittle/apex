-- Apex Scheduler multi-tenant SaaS model.
-- Adds businesses, invitations, configurable roles, locations, business_id
-- scoping on all venue-specific tables, and row-level security policies.

-- ---------------------------------------------------------------------------
-- Businesses
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

-- Migrate legacy organizations row(s) into businesses when present.
insert into businesses (id, name, industry_type, plan_tier, created_at)
select o.id, o.name, 'other', 'free', o.created_at
from organizations o
on conflict (id) do nothing;

-- Seed a default business for existing single-tenant data (idempotent).
insert into businesses (id, name, industry_type, plan_tier)
values (
  '00000000-0000-0000-0000-000000000001',
  'Legacy Workspace',
  'other',
  'free'
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Profiles — bind users to a business
-- ---------------------------------------------------------------------------
alter table profiles
  add column if not exists business_id uuid references businesses(id);

update profiles
  set business_id = coalesce(business_id, organization_id, '00000000-0000-0000-0000-000000000001')
  where business_id is null;

-- New signups must complete onboarding or join via invite code.
alter table profiles alter column business_id drop default;

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------
create table if not exists invitations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  code text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  max_uses int,
  use_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists invitations_business_id_idx on invitations(business_id);
create index if not exists invitations_code_idx on invitations(code);

-- ---------------------------------------------------------------------------
-- Configurable roles (position names) per business
-- ---------------------------------------------------------------------------
create table if not exists business_roles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (business_id, name)
);

create index if not exists business_roles_business_id_idx on business_roles(business_id);

-- Seed default roles for existing businesses.
insert into business_roles (business_id, name, sort_order)
select b.id, role_name, ord
from businesses b
cross join (values ('Team Member', 0), ('Supervisor', 1), ('Manager', 2)) as defaults(role_name, ord)
on conflict (business_id, name) do nothing;

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

create index if not exists locations_business_id_idx on locations(business_id);

-- Default location for each existing business.
insert into locations (business_id, name, address)
select b.id, 'Main Location', null
from businesses b
where not exists (
  select 1 from locations l where l.business_id = b.id
);

-- ---------------------------------------------------------------------------
-- Tenant columns on operational tables
-- ---------------------------------------------------------------------------
alter table shifts add column if not exists business_id uuid references businesses(id);
alter table shifts add column if not exists location_id uuid references locations(id);

update shifts
  set business_id = '00000000-0000-0000-0000-000000000001'
  where business_id is null;

alter table swaps add column if not exists business_id uuid references businesses(id);
update swaps set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

alter table availability add column if not exists business_id uuid references businesses(id);
update availability set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

alter table time_off_requests add column if not exists business_id uuid references businesses(id);
update time_off_requests set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

alter table time_entries add column if not exists business_id uuid references businesses(id);
update time_entries set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

alter table sidework add column if not exists business_id uuid references businesses(id);
update sidework set business_id = '00000000-0000-0000-0000-000000000001' where business_id is null;

-- ---------------------------------------------------------------------------
-- Helper: current user's business_id (for RLS)
-- ---------------------------------------------------------------------------
create or replace function public.current_business_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select business_id from profiles where id = auth.uid()
$$;

create or replace function public.is_business_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from profiles p
    join businesses b on b.id = p.business_id
    where p.id = auth.uid()
      and (p.role = 'Owner' or b.owner_id = auth.uid())
  )
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table businesses enable row level security;
alter table profiles enable row level security;
alter table invitations enable row level security;
alter table business_roles enable row level security;
alter table locations enable row level security;
alter table shifts enable row level security;
alter table swaps enable row level security;
alter table availability enable row level security;
alter table time_off_requests enable row level security;
alter table time_entries enable row level security;
alter table sidework enable row level security;

-- Businesses
drop policy if exists "businesses_select_own" on businesses;
create policy "businesses_select_own" on businesses
  for select using (id = public.current_business_id());

drop policy if exists "businesses_insert_owner" on businesses;
create policy "businesses_insert_owner" on businesses
  for insert with check (owner_id = auth.uid());

drop policy if exists "businesses_update_owner" on businesses;
create policy "businesses_update_owner" on businesses
  for update using (owner_id = auth.uid() or id = public.current_business_id() and public.is_business_owner());

-- Profiles
drop policy if exists "profiles_select_same_business" on profiles;
create policy "profiles_select_same_business" on profiles
  for select using (business_id = public.current_business_id() or id = auth.uid());

drop policy if exists "profiles_insert_self" on profiles;
create policy "profiles_insert_self" on profiles
  for insert with check (id = auth.uid());

drop policy if exists "profiles_update_self_or_owner" on profiles;
create policy "profiles_update_self_or_owner" on profiles
  for update using (
    id = auth.uid()
    or (business_id = public.current_business_id() and public.is_business_owner())
  );

-- Invitations
drop policy if exists "invitations_select_same_business" on invitations;
create policy "invitations_select_same_business" on invitations
  for select using (business_id = public.current_business_id());

drop policy if exists "invitations_manage_owner" on invitations;
create policy "invitations_manage_owner" on invitations
  for all using (business_id = public.current_business_id() and public.is_business_owner())
  with check (business_id = public.current_business_id() and public.is_business_owner());

-- Allow invite lookup by code during signup (anon/authenticated read by code only via RPC or open select on code match)
drop policy if exists "invitations_select_by_code" on invitations;
create policy "invitations_select_by_code" on invitations
  for select using (true);

-- Business roles
drop policy if exists "roles_select_same_business" on business_roles;
create policy "roles_select_same_business" on business_roles
  for select using (business_id = public.current_business_id());

drop policy if exists "roles_manage_owner" on business_roles;
create policy "roles_manage_owner" on business_roles
  for all using (business_id = public.current_business_id() and public.is_business_owner())
  with check (business_id = public.current_business_id() and public.is_business_owner());

-- Locations
drop policy if exists "locations_select_same_business" on locations;
create policy "locations_select_same_business" on locations
  for select using (business_id = public.current_business_id());

drop policy if exists "locations_manage_owner" on locations;
create policy "locations_manage_owner" on locations
  for all using (business_id = public.current_business_id() and public.is_business_owner())
  with check (business_id = public.current_business_id() and public.is_business_owner());

-- Generic tenant-scoped tables
do $$
declare
  tbl text;
begin
  foreach tbl in array array['shifts', 'swaps', 'availability', 'time_off_requests', 'time_entries', 'sidework']
  loop
    execute format('drop policy if exists "%s_select_same_business" on %I', tbl, tbl);
    execute format(
      'create policy "%s_select_same_business" on %I for select using (business_id = public.current_business_id())',
      tbl, tbl
    );
    execute format('drop policy if exists "%s_insert_same_business" on %I', tbl, tbl);
    execute format(
      'create policy "%s_insert_same_business" on %I for insert with check (business_id = public.current_business_id())',
      tbl, tbl
    );
    execute format('drop policy if exists "%s_update_same_business" on %I', tbl, tbl);
    execute format(
      'create policy "%s_update_same_business" on %I for update using (business_id = public.current_business_id())',
      tbl, tbl
    );
    execute format('drop policy if exists "%s_delete_same_business" on %I', tbl, tbl);
    execute format(
      'create policy "%s_delete_same_business" on %I for delete using (business_id = public.current_business_id())',
      tbl, tbl
    );
  end loop;
end $$;

-- Paying venues metric (updated for businesses)
create or replace view v_paying_venues as
select b.id as business_id, b.name
from businesses b
where b.plan_tier = 'pro';
