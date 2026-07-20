-- Launch-blocker RLS: enforce per-organization tenant isolation.
--
-- Context: org_workspace_model added `organization_id` to profiles/shifts but
-- deliberately left RLS off ("hard prerequisite before onboarding a second
-- real venue"). The audit (2026-07-19) confirmed hot reads/streams are scoped
-- by date only, so a second venue would see the first venue's data. This
-- migration closes that at the database layer — the only layer a forgotten
-- client `.eq()` can't bypass.
--
-- ⚠️ APPLY TO STAGING FIRST. Enabling RLS is default-deny: any operation the
-- app performs that a policy below does not cover will start failing. The
-- policies here were written against the app's actual query set as of
-- 2026-07-20 (shifts, swaps, time_entries, time_off_requests, notifications,
-- profiles). Smoke-test sign-in, calendar load, claim, clock in/out, swap
-- post/approve, and notifications on staging before promoting to prod.
--
-- Idempotent: safe to re-run (drop policy if exists → create; add column if
-- not exists; enable RLS is a no-op when already on).

begin;

-- ---------------------------------------------------------------------------
-- 0. Backfill org columns on tables that lack them.
--    Only one venue (Jigsy's, org …0001) exists today, so NULLs backfill to it.
-- ---------------------------------------------------------------------------
alter table public.swaps
  add column if not exists organization_id uuid references public.organizations(id);
update public.swaps
  set organization_id = '00000000-0000-0000-0000-000000000001'
  where organization_id is null;
alter table public.swaps
  alter column organization_id set default '00000000-0000-0000-0000-000000000001';
create index if not exists idx_swaps_organization_id on public.swaps(organization_id);

-- time_entries has no org column; it is scoped through its owning user's
-- profile instead (user_id → profiles.organization_id). No column added.
create index if not exists idx_time_entries_user_id on public.time_entries(user_id);

-- ---------------------------------------------------------------------------
-- 1. Caller's organization. SECURITY DEFINER so it can read profiles even
--    with RLS enabled (no recursion: the function bypasses RLS).
-- ---------------------------------------------------------------------------
create or replace function public.apex_current_org()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select organization_id from public.profiles where id = auth.uid()
$$;
grant execute on function public.apex_current_org() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Fully-atomic clock-in guard: at most one open entry per user+shift.
--    Complements the client-side check in TimeClockService.clockIn.
-- ---------------------------------------------------------------------------
create unique index if not exists uq_time_entries_open
  on public.time_entries(user_id, shift_id)
  where clock_out is null;

-- ---------------------------------------------------------------------------
-- 3. Enable RLS + policies. All access is limited to the caller's org.
--    SECURITY DEFINER RPCs (apex_create_organization, apex_notify_user) and
--    edge functions using the service role bypass these policies as intended.
-- ---------------------------------------------------------------------------

-- profiles: read the roster of your own org; write only your own row (signup +
-- self-edit). Org creation / role assignment goes through SECURITY DEFINER RPCs.
alter table public.profiles enable row level security;
drop policy if exists apex_profiles_select on public.profiles;
create policy apex_profiles_select on public.profiles
  for select to authenticated
  using (organization_id = public.apex_current_org());
drop policy if exists apex_profiles_insert on public.profiles;
create policy apex_profiles_insert on public.profiles
  for insert to authenticated
  with check (id = auth.uid());
drop policy if exists apex_profiles_update on public.profiles;
create policy apex_profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- organizations: you can see your own org row.
alter table public.organizations enable row level security;
drop policy if exists apex_org_select on public.organizations;
create policy apex_org_select on public.organizations
  for select to authenticated
  using (id = public.apex_current_org());

-- shifts: full CRUD within your org (has organization_id).
alter table public.shifts enable row level security;
drop policy if exists apex_shifts_all on public.shifts;
create policy apex_shifts_all on public.shifts
  for all to authenticated
  using (organization_id = public.apex_current_org())
  with check (organization_id = public.apex_current_org());

-- swaps: full CRUD within your org (org column added above).
alter table public.swaps enable row level security;
drop policy if exists apex_swaps_all on public.swaps;
create policy apex_swaps_all on public.swaps
  for all to authenticated
  using (organization_id = public.apex_current_org())
  with check (organization_id = public.apex_current_org());

-- time_off_requests: full CRUD within your org (has organization_id).
alter table public.time_off_requests enable row level security;
drop policy if exists apex_time_off_all on public.time_off_requests;
create policy apex_time_off_all on public.time_off_requests
  for all to authenticated
  using (organization_id = public.apex_current_org())
  with check (organization_id = public.apex_current_org());

-- time_entries: no org column — scope through the owning user's org. You may
-- read any same-org entry (payroll/export) but only write your own.
alter table public.time_entries enable row level security;
drop policy if exists apex_time_entries_select on public.time_entries;
create policy apex_time_entries_select on public.time_entries
  for select to authenticated
  using (user_id in (
    select id from public.profiles where organization_id = public.apex_current_org()
  ));
drop policy if exists apex_time_entries_write on public.time_entries;
create policy apex_time_entries_write on public.time_entries
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- notifications: you manage only your own. Rows are created by the
-- SECURITY DEFINER apex_notify_user RPC, so no INSERT policy is needed here.
alter table public.notifications enable row level security;
drop policy if exists apex_notifications_select on public.notifications;
create policy apex_notifications_select on public.notifications
  for select to authenticated
  using (user_id = auth.uid());
drop policy if exists apex_notifications_update on public.notifications;
create policy apex_notifications_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

commit;
