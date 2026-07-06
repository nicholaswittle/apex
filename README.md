# Apex Scheduler

Multi-tenant shift scheduling SaaS for restaurants, retail, gyms, clinics, and any hourly workforce — shifts, swaps, time clock, sidework, labor cost, and owner billing.

| | |
|--|--|
| **Bundle ID** | `com.wisense.apex` |
| **Stack** | Flutter · Supabase · Firebase Cloud Messaging · Stripe |
| **Platforms** | iOS · Android · Web |

## Monorepo layout

This app depends on shared WiSense packages (vendored under `packages/` for standalone builds):

```
packages/wisense_core/
packages/wisense_ui/
lib/
supabase/migrations/
```

## Quick start

```bash
cp .env.local.example .env.local   # fill in Supabase + Stripe keys
flutter pub get
./scripts/run_dev.sh
```

## Multi-tenant setup

Apply the Supabase migration before onboarding a second business:

```bash
supabase db push
# or run supabase/migrations/001_multi_tenant.sql manually
```

See `docs/MULTI_TENANT_MIGRATION_PLAN.md` for architecture notes.

## Store launch

See **[docs/LAUNCH_CHECKLIST.md](docs/LAUNCH_CHECKLIST.md)** for TestFlight and Play Store steps.

## Environment variables

| Variable | Required | Notes |
|----------|----------|-------|
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Public anon key |
| `STRIPE_PUBLISHABLE_KEY` | Owner billing | Payment Sheet on billing page |

## Features

- Multi-tenant businesses with RLS isolation
- Owner onboarding and staff invite codes
- Configurable shift roles per business
- Free tier (1 location, 10 staff) and Pro tier
- Shift calendar, swaps, time off, time clock
- Owner dashboard with live metrics
- Stripe billing (Edge Function)
