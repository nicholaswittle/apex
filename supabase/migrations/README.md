# Supabase migrations

Remote migrations applied to the Apex Supabase project:

| Migration | Description |
|-----------|-------------|
| `launch_blockers_foundation` | `shift_date` / `task_date`, swap claim columns, day sync triggers |
| `launch_blockers_rls_and_auth` | RLS hardening, owner bootstrap, subscription protection |
| `launch_blockers_rls_hotfix` | Staff shift update policy, subscription RPC trigger bypass |
| `launch_blockers_owner_check_rpc` | `apex_has_owner()` for setup flow |
| `launch_complete_features` | Sidework completion, notifications table, invite RPC, push notify RPC, Stripe webhook RPC |
| `user_id_backfill` | `shifts.user_id` column + backfill from profiles (applied 20260708194039) |

Edge functions deployed:

- `create-payment-intent`
- `stripe-webhook`
- `send-push-notification`

Configure secrets in Supabase Dashboard before production use. See `docs/LAUNCH_CHECKLIST.md`.
