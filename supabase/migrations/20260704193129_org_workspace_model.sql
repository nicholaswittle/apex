-- Multi-tenant workspace model for Apex.
--
-- Apex currently has one paying venue (Jigsy's Brewpub) sharing a single
-- `profiles` table with no organization concept at all. Two places already
-- query `profiles` completely unscoped by venue:
--   - lib/billing_page.dart: staff count (drives pricing tier) sums every
--     row in the table, regardless of venue.
--   - lib/calendar_page.dart _loadStaffNames(): the staff roster (names,
--     roles, hourly rates) is fetched globally, no venue filter.
-- Both would break the moment a second venue signs up: Venue B's owner
-- would see Venue A's staff roster and pricing tier would double-count
-- across venues. This migration adds the minimum schema needed to fix that
-- at the app-query level. It intentionally does NOT add Row Level Security
-- policies — see docs/MULTI_TENANT_MIGRATION_PLAN.md for why, and treat RLS
-- as a hard prerequisite before onboarding a second real venue.

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

-- Org #1 — Apex's first paying venue. Fixed UUID so this migration is
-- idempotent and app-layer code can reference it if ever needed.
insert into organizations (id, name)
values ('00000000-0000-0000-0000-000000000001', 'Jigsy''s Brewpub')
on conflict (id) do nothing;

alter table profiles
  add column if not exists organization_id uuid references organizations(id);

-- Every profile created before this migration predates the org model and
-- belongs to Apex's only venue so far.
update profiles
  set organization_id = '00000000-0000-0000-0000-000000000001'
  where organization_id is null;

-- New signups default to Jigsy's Brewpub until a venue-onboarding flow
-- exists (auth_page.dart's signup insert is intentionally left untouched —
-- this default means it keeps working exactly as before, without needing
-- an organization_id in the insert payload).
alter table profiles
  alter column organization_id set default '00000000-0000-0000-0000-000000000001';

-- From docs/BILLING_DEPLOY.md — folded in here so this single migration is
-- a complete "run once" script if that step hasn't been applied yet.
alter table profiles
  add column if not exists subscription_status text default 'inactive';
