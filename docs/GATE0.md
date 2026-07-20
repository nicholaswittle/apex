# Gate 0 — Stabilize & Baseline

**Status:** Active  
**Rule:** No Pillar 0 merges, no Smart Suggestions on main, no billing until Gate 0 exit.

Full roadmap: [ROADMAP.md](ROADMAP.md)  
Baseline file: [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md)

---

## Merge & Deploy (before Day 1)

- [ ] Merge latest launch-blockers into production branch (see note below)
- [ ] Vercel **Production Branch** = `cursor/launch-blockers-fix-7c60` (or merged target — verify in UI)
- [ ] Env vars on Vercel **Production + Preview:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- [ ] Supabase **Authentication → Redirect URLs** include Vercel production domain
- [ ] Hard refresh / incognito: login → calendar → publish → sidework → swap view
- [ ] Deployment Protection on Preview: disabled **or** document bypass URL ([VERCEL.md](VERCEL.md))
- [ ] Record deployed commit SHA in [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md)

**Branch note (July 2026):** PR #5 merged into `cursor/apex-store-launch-447c`, but `cursor/launch-blockers-fix-7c60` has two additional commits (Vercel white-screen fix). Merge or set Vercel to the branch with the latest fixes before starting Day 1.

---

## Baseline Session (complete by Day 3)

Schedule 30 minutes with Jigsy's owner. Timed live build of **next week's schedule** (stopwatch).

Fill every row in [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md) and commit.

---

## 7-Day Clean Run

Start only after deploy is confirmed. Log daily in [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md).

| Day | Done |
|-----|------|
| 1 | ☐ |
| 2 | ☐ |
| 3 | ☐ |
| 4 | ☐ |
| 5 | ☐ |
| 6 | ☐ |
| 7 | ☐ |

**P0 → clock resets to Day 1:** publish · auth/invite · swap/realtime · CSV export

---

## Gate 0 Exit (all required)

- [ ] 7 consecutive days, zero P0
- [ ] [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md) complete with owner sign-off
- [ ] `flutter analyze && flutter test` green on deployed commit SHA
- [ ] No open P0 GitHub issues

---

## Allowed during Gate 0 (branch-only, no main merge)

- [pillar0/CALENDAR_MODULE_MAP.md](pillar0/CALENDAR_MODULE_MAP.md) — refactor plan
- [pillar0/MIGRATION_INVENTORY.md](pillar0/MIGRATION_INVENTORY.md) — SQL to vendor
- [pillar0/E2E_SMOKE_SPEC.md](pillar0/E2E_SMOKE_SPEC.md) — test spec
- [pillar0/SMART_SUGGESTIONS_SPIKE.md](pillar0/SMART_SUGGESTIONS_SPIKE.md) — read-only spike
- Sentry spike branch

---

## Forbidden until Gate 0 exit

- Pillar 0 production merges (calendar refactor, user_id migration)
- Smart Suggestions on main
- `AppConfig.billingEnabled = true`
- Customer #2 onboarding work
- New strategy documents
