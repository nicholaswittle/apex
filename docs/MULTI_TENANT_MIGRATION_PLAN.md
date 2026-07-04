# Apex multi-tenant migration plan

## What's done (this pass)

- `organizations` table + `profiles.organization_id`, backfilled to Jigsy's
  Brewpub (org #1) for every existing profile, defaulted for new signups.
  See `supabase/migrations/20260704193129_org_workspace_model.sql`.
- `profiles.subscription_status` column (from `docs/BILLING_DEPLOY.md`),
  folded into the same migration so it's a single "run once" script.
- Fixed two queries that were completely unscoped by venue and would have
  broken the moment a second venue signed up:
  - `lib/billing_page.dart` — staff count (drives pricing tier) now scoped
    to the current user's `organization_id`.
  - `lib/calendar_page.dart` `_loadStaffNames()` — staff roster (names,
    roles, hourly rates) now scoped to `organization_id`.
- `v_paying_venues` view for the paying-venues north-star metric.
  `supabase/migrations/20260704193613_paying_venues_metric.sql`.

None of this required a schema change to `auth_page.dart`'s signup flow —
new profiles get `organization_id` from the column default, so login/signup
behavior is unchanged.

## What's NOT done — required before onboarding a second real venue

**Row Level Security (RLS) is not enabled on `profiles` (or any other
table).** The scoping fixes above are app-level query filters — they stop
the app's own UI from *showing* cross-venue data, but they do **not**
stop a client from calling the Supabase REST API directly with the anon
key and reading every venue's data regardless of `organization_id`. Right
now that's a theoretical risk (Apex has exactly one venue, so there's
nothing to leak between tenants yet). It stops being theoretical the day
venue #2 signs up.

Before that happens, add RLS policies scoping `profiles` (and any other
venue-specific tables — `time_off_requests`, shifts, whatever else exists)
to `auth.uid()`'s `organization_id`. This needs live testing against a real
login before shipping — a wrong policy can lock out signup/login entirely,
which is a worse failure mode than the current single-tenant gap. Don't
attempt this without being able to test signup + login end-to-end
afterward.

**Other unscoped queries may still exist.** This pass fixed the two most
consequential ones (billing math, staff roster). A full audit of every
`.from('profiles')` / `.from('time_off_requests')` / etc. call for
cross-venue leakage hasn't been done.

**Billing is still keyed to whichever profile row is "the owner," not to
the organization.** `subscription_status` lives on `profiles`, not
`organizations`. This works fine today (one owner per venue, so their row
is unambiguous) but isn't a clean design — if a venue ever has multiple
"owner"-role accounts, or ownership transfers, this could get confusing.
Moving `subscription_status` to `organizations` would be the more correct
long-term design, but is out of scope for "don't break current login."

## Full Supabase project split (deferred, per explicit instruction)

Apex currently shares one Supabase project (`cyokzxwztctjuqqygbam`) with
New Horizon and Horizon V2. A full split to a dedicated Apex project would
mean: new Supabase project, re-running all migrations there, migrating
existing Jigsy's Brewpub data, updating `AppConfig.supabaseUrl` /
`supabaseAnonKey` (and any Vercel env vars for the Edge Function), and
updating `SUPABASE_SERVICE_ROLE_KEY` used by `create-payment-intent`.

This is a real project on its own — probably a half-day of careful work
plus a maintenance window, not something to do inline with a billing
deploy. Reasons to eventually do it: Apex is a paid B2B product with real
customer data; New Horizon is a consumer app with different scaling/compliance
needs; keeping them on one project means one outage or one bad migration
affects both. Reasons it's not urgent: at one venue, isolation risk is
zero, and RLS (above) solves the more pressing multi-tenant problem
without a project split.

**Recommendation:** do RLS first (blocks real harm), do the project split
later, ideally before or right around onboarding a 3rd-4th venue rather
than before the 2nd.
