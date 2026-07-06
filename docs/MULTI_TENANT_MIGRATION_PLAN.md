# Apex multi-tenant migration plan

## Status: COMPLETE (TASK-1783298712767)

The multi-tenant SaaS rebuild is implemented. See `supabase/migrations/001_multi_tenant.sql` and `docs/task-results/TASK-1783298712767.md`.

### What's done

- `businesses` table with `plan_tier`, `industry_type`, `owner_id`
- `business_id` on `profiles`, `shifts`, `swaps`, `availability`, `time_off_requests`, `time_entries`, `sidework`
- `invitations`, `business_roles`, `locations` tables
- Row Level Security on all tenant-scoped tables via `current_business_id()`
- Owner onboarding (`BusinessSetupScreen`) and staff invite-by-code flow
- Freemium gates via `PlanService` (10 staff / 1 location on free tier)
- Dashboard, role config, upgrade UI, location selector
- Rebrand to **Apex Scheduler** — Jigsy/brewpub references removed from app code

### Legacy migrations

Earlier migrations (`20260704193129_org_workspace_model.sql`) introduced `organizations` /
`organization_id`. Migration `001_multi_tenant.sql` migrates that data into `businesses` /
`business_id`. Apply in chronological order on existing projects.

### Deferred

- Dedicated Supabase project split (still shares project with other WiSense apps)
- Live Stripe / RevenueCat payment wiring (manual `plan_tier` upgrade path exists for beta)

### QA checklist (post-deploy)

1. Sign up as Owner A → create business → confirm dashboard shows correct data
2. Sign up as Owner B → create second business → confirm zero data bleed from A
3. Generate invite code as Owner A → staff signup with code → staff sees only A's schedule
4. Free tier: attempt 11th staff invite → blocked with upgrade prompt
5. Free tier: attempt second location → blocked with upgrade prompt
