# Supabase migrations

Remote migrations applied to the Apex Supabase project:

| Migration | Description |
|-----------|-------------|
| `20260720000000_launch_blockers_rls` | **Vendored 2026-07-20.** Per-org RLS isolation (profiles/shifts/swaps/time_entries/time_off_requests/notifications), `apex_current_org()` helper, partial unique index for atomic clock-in. Adds `organization_id` to `swaps`. ⚠️ Apply to **staging first** — RLS is default-deny. |
| `launch_blockers_foundation` | `shift_date` / `task_date`, swap claim columns, day sync triggers |
| `launch_blockers_rls_and_auth` | RLS hardening, owner bootstrap, subscription protection |
| `launch_blockers_rls_hotfix` | Staff shift update policy, subscription RPC trigger bypass |
| `launch_blockers_owner_check_rpc` | `apex_has_owner()` for setup flow |
| `launch_complete_features` | Sidework completion, notifications table, invite RPC, push notify RPC, Stripe webhook RPC |
| `user_id_backfill` | `shifts.user_id` column + backfill from profiles (applied 20260708194039) |
| `apex_create_organization` | `apex_create_organization()` RPC for multi-business owner signup |
| `time_off_realtime` | Realtime on `time_off_requests` + `notifications` for live status updates |

Edge functions deployed:

- `create-payment-intent`
- `stripe-webhook`
- `send-push-notification`

Configure secrets in Supabase Dashboard before production use. See `docs/LAUNCH_CHECKLIST.md`.
