# Deploy Apex Scheduler web to Vercel (testing)

Use this to test audit fixes in the browser without a Mac or Android build.

## 1. Vercel project setup

1. Import the GitHub repo at [vercel.com](https://vercel.com)
2. **Framework preset:** Other (uses `vercel.json` in repo root)
3. **Root directory:** repository root (where `pubspec.yaml` lives)

## 2. Environment variables

In Vercel → Project → Settings → Environment Variables, add:

| Variable | Value |
|----------|--------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anon/public key |

Apply to **Production**, **Preview**, and **Development**.

These are baked in at build time via `--dart-define`.

## 3. Supabase auth URLs

In Supabase Dashboard → **Authentication** → **URL Configuration**:

| Field | Value |
|-------|--------|
| **Site URL** | `https://your-app.vercel.app` |
| **Redirect URLs** | `https://your-app.vercel.app/**` and `http://localhost:**` |

Without this, login may fail on the deployed domain.

## 4. Deploy

Push to your branch — Vercel builds automatically.

Manual local web build:

```bash
cp .env.local.example .env.local   # fill Supabase keys
chmod +x scripts/build_web.sh
./scripts/build_web.sh
# Serve build/web with any static server, e.g.:
python3 -m http.server 8080 --directory build/web
```

## 5. What works on web

| Feature | Web |
|---------|-----|
| Auth (email/password) | Yes |
| Shift calendar, swaps, time off | Yes |
| Sidework completion | Yes |
| Org invites (owner) | Yes |
| In-app notifications | Yes |
| CSV export | Download + clipboard |
| Push notifications | No (mobile only) |
| Billing | Deferred (coming soon) |

## 6. Troubleshooting

### F12 console: manifest.json CORS / vercel.com/sso-api redirect

Your preview URL has **Vercel Deployment Protection** enabled. Static files like `manifest.json` redirect to Vercel SSO, which causes CORS errors in the browser console.

**Fix:** Vercel → Project → **Settings → Deployment Protection** → set Preview deployments to **Standard Protection (only production)** or disable protection for the environment you share with staff. Then redeploy.

Use your **production** domain for team testing, not `*-wi-sense-llc.vercel.app` preview URLs, unless previews are public.

### F12 console: shifts 400 Bad Request

Old builds insert shifts without `shift_date` (required). Deploy branch `cursor/calendar-swipe-nav-7c60` (PR #6) or merge to production. A DB back-compat trigger now derives dates from `day_num` for older clients, but the fixed app build is still recommended.

### F12 console: auth 422 / 400

| Code | Meaning |
|------|---------|
| **422 signup** | Email already registered — use Sign In |
| **400 login** | Wrong password or email not confirmed |

Add your Vercel URL to Supabase **Authentication → URL Configuration → Redirect URLs**.

### F12 console: Noto fonts warning

Harmless Flutter web warning. `web/index.html` preloads Noto Sans to reduce it.

**"Supabase not configured" screen**  
Vercel env vars missing or deploy happened before they were set → add vars → **Redeploy**.

**Blank page after deploy**  
Check Vercel build logs. First build installs Flutter (~2–4 min).

**Login works locally but not on Vercel**  
Add your exact Vercel URL to Supabase redirect URLs.

**CORS / API errors**  
Confirm `SUPABASE_URL` matches your project and anon key is correct.

## 7. Not in scope for web testing

- Stripe billing (deferred)
- Firebase push (mobile only)
- App Store / Play Store builds

Focus on scheduling audit fixes: dates, swaps, sidework, auth, invites, notifications.
