# Apex multi-tenant migration plan

## What's done (TASK-1783298712767)

- Full `businesses` table with `plan_tier`, `industry_type`, `owner_id`
- `profiles.business_id` replaces org-scoped membership
- `locations`, `roles`, `invitations` tables
- `business_id` on all operational tables (shifts, availability, time off, etc.)
- Row Level Security on all tenant tables via `current_user_business_id()`
- Owner onboarding (`BusinessSetupScreen`) and staff invite-by-code flow
- Configurable roles per business (`RoleConfigScreen`)
- Freemium gating via `PlanService` (10 staff / 1 location on free tier)
- Owner dashboard with live business metrics
- Multi-location selector on schedule view
- Rebrand to **Apex Scheduler** — Jigsy/brewpub references removed

See `supabase/migrations/001_multi_tenant.sql` and `docs/TASK-1783298712767_RESULT.md`.

## Deferred

- Full Supabase project split from New Horizon / Horizon V2 (see prior plan)
- Live Stripe / RevenueCat checkout for Pro upgrades (beta uses manual `plan_tier` write)
- Moving `subscription_status` from `profiles` to `businesses` (long-term cleanup)

## Manual QA before second production tenant

1. Apply `001_multi_tenant.sql` to Supabase.
2. Log in as two different owners — confirm zero data bleed.
3. Confirm free-tier caps block staff invites and second locations.
4. Confirm staff with invite code only sees their business schedule.
