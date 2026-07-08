# Pillar 0 — Migration inventory

Remote migrations were applied to Supabase project `pqkremkwfkudrhtxasdj`. **Goal:** vendor equivalent SQL into `supabase/migrations/` for reproducible deploys.

See [supabase/migrations/README.md](../../supabase/migrations/README.md) for names already documented.

---

## Migrations to vendor (priority order)

| ID | Name (logical) | Contents | Status |
|----|----------------|----------|--------|
| M1 | `launch_blockers_foundation` | `shift_date` / `task_date`, swap claim columns, day sync triggers | Documented, SQL pending |
| M2 | `launch_blockers_rls_and_auth` | RLS hardening, owner bootstrap, subscription protection | Documented, SQL pending |
| M3 | `launch_blockers_rls_hotfix` | Staff shift update policy, subscription RPC trigger bypass | Documented, SQL pending |
| M4 | `launch_blockers_owner_check_rpc` | `apex_has_owner()` for setup flow | Documented, SQL pending |
| M5 | `launch_complete_features` | Sidework completion, notifications, invite RPC, push notify RPC, Stripe webhook RPC | Documented, SQL pending |

---

## Pillar 0 new migrations (to author)

| ID | Name | Purpose |
|----|------|---------|
| M6 | `user_id_backfill` | Add/populate `user_id` on shifts where only `staff` name exists |
| M7 | `analytics_events` _(optional)_ | Table or use client-side only until Pillar A |

---

## Workflow (after Gate 0)

```bash
# Install Supabase CLI, link project
supabase link --project-ref pqkremkwfkudrhtxasdj

# Pull remote schema diff (when CLI available)
supabase db pull

# Or hand-author from dashboard SQL history → supabase/migrations/YYYYMMDDHHMMSS_name.sql
supabase db push   # staging only first
```

**Rule:** Never apply untested migration to production during Jigsy's service hours.

---

## Edge functions (already deployed)

| Function | Purpose |
|----------|---------|
| `create-payment-intent` | Stripe (deferred) |
| `stripe-webhook` | Stripe (deferred) |
| `send-push-notification` | FCM relay |

Vendor function source into `supabase/functions/` when billing goes live (Pillar D).

---

## RPCs referenced in app code

| RPC | File |
|-----|------|
| `apex_redeem_invite` | `lib/core/profile_service.dart` |
| `apex_has_owner` | setup flow (see migrations README) |

Confirm signatures match Flutter client before Pillar 0 exit.
