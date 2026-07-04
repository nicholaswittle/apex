# Apex billing — Supabase Edge Function deploy

The Flutter app calls `create-payment-intent` for Stripe Payment Sheet checkout and for server-side subscription activation. Deploy this from a machine with the [Supabase CLI](https://supabase.com/docs/guides/cli), or paste the function into the Supabase dashboard.

## Secrets (Supabase → Project Settings → Edge Functions)

| Secret | Required |
|--------|----------|
| `STRIPE_SECRET_KEY` | Yes — Stripe secret key (`sk_test_…` or `sk_live_…`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes — used to update `profiles.subscription_status` after verified payment |

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected automatically in hosted Edge Functions.

## Deploy

```bash
cd projects/apex/apex
supabase link --project-ref cyokzxwztctjuqqygbam
supabase db push  # applies supabase/migrations/*.sql, including org/workspace model + subscription_status
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx SUPABASE_SERVICE_ROLE_KEY=eyJ...
supabase functions deploy create-payment-intent
```

## Actions

| `action` (body) | Behavior |
|-----------------|----------|
| *(omit)* | Creates Stripe customer (if needed), PaymentIntent, ephemeral key |
| `activate_subscription` | Verifies PaymentIntent status is `succeeded`, sets `subscription_status = active` |
| `cancel_subscription` | Sets `subscription_status = inactive` for the signed-in owner |

## SQL

Now tracked as versioned migrations in `supabase/migrations/` — run via
`supabase db push`, or paste each file's contents into the SQL editor in
order if you don't have CLI access:

1. `20260704193129_org_workspace_model.sql` — adds `organizations`,
   `profiles.organization_id` (backfilled to Jigsy's Brewpub), and
   `profiles.subscription_status`. See
   `docs/MULTI_TENANT_MIGRATION_PLAN.md` for what this does and doesn't
   cover (in particular: no RLS yet — read that before onboarding a
   second venue).
2. `20260704193613_paying_venues_metric.sql` — adds the `v_paying_venues`
   view used for the paying-venues north-star metric
   (`select count(*) from v_paying_venues;`).

## Phone checklist

1. Supabase dashboard → SQL editor → run the two migration files above, in order (if not already applied)
2. Supabase dashboard → Edge Functions → deploy `create-payment-intent`
3. Set secrets above
4. Merge Apex security PR and let Vercel redeploy web
5. Test billing on https://apex-scheduler-theta.vercel.app as an owner account
