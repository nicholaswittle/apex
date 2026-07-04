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
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx SUPABASE_SERVICE_ROLE_KEY=eyJ...
supabase functions deploy create-payment-intent
```

## Actions

| `action` (body) | Behavior |
|-----------------|----------|
| *(omit)* | Creates Stripe customer (if needed), PaymentIntent, ephemeral key |
| `activate_subscription` | Verifies PaymentIntent status is `succeeded`, sets `subscription_status = active` |
| `cancel_subscription` | Sets `subscription_status = inactive` for the signed-in owner |

## SQL (run once if missing)

```sql
alter table profiles add column if not exists subscription_status text default 'inactive';
```

## Phone checklist

1. Supabase dashboard → Edge Functions → deploy `create-payment-intent`
2. Set secrets above
3. Merge Apex security PR and let Vercel redeploy web
4. Test billing on https://apex-scheduler-theta.vercel.app as an owner account
