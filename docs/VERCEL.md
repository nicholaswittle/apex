# Deploy Apex Scheduler web to Vercel (testing)

Use this to test audit fixes in the browser without a Mac or Android build.

## Production URL (use this one)

**https://apex-scheduler-theta.vercel.app**

Do **not** use `apex-scheduler.vercel.app` — that domain points to a different old project ("Apex Radar") without the Flutter build.

| URL | Status |
|-----|--------|
| `apex-scheduler-theta.vercel.app` | ✅ Apex Scheduler (correct) |
| `apex-scheduler.vercel.app` | ❌ Wrong project — JS 404 |
| `*-wi-sense-llc.vercel.app` previews | ⚠️ May have Deployment Protection — use theta instead |

**One branch, one deploy:** push to `cursor/apex-store-launch-447c` → Vercel auto-builds production (~3–5 min).

## GitHub Actions deploy (optional)

Workflow `.github/workflows/vercel-deploy.yml` deploys on push to the production branch.
Add these **GitHub repository secrets**:

| Secret | Source |
|--------|--------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon key |
| `VERCEL_TOKEN` | Vercel → Account → Tokens |
| `VERCEL_ORG_ID` | Vercel project settings |
| `VERCEL_PROJECT_ID` | Vercel project settings |

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
| **Site URL** | `https://apex-scheduler.vercel.app` |
| **Redirect URLs** | `https://apex-scheduler.vercel.app/**`, `https://*.vercel.app/**`, `http://localhost:**` |

These are configured on Supabase project `pqkremkwfkudrhtxasdj` (July 2026).

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

### F12 console: white screen / blank page

1. **Hard refresh** — old service worker may cache a broken deploy: open site → browser menu → clear cache / hard reload.
2. **Vercel env vars** — `SUPABASE_URL` and `SUPABASE_ANON_KEY` must be set for **Preview** and **Production**, then **Redeploy**. Without them you should see a "Supabase not configured" screen (not white).
3. **Deployment Protection** — preview iframes often show white; tap **Visit** or disable protection for previews.
4. **Check browser console** — if JS fails to load, index.html now shows a red error message instead of a blank page.

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
