# Apex Scheduler — Product Roadmap

**Pilot:** Jigsy's Brewpub (free design partner)  
**Stack:** Flutter · Supabase · Firebase Cloud Messaging  
**Billing:** Deferred (`AppConfig.billingEnabled = false`)

**Current phase:** [Gate 0](GATE0.md) — stabilize, baseline, 7 clean days.

---

## Vision

Trusted, intelligent scheduling for independent hospitality (5–50 employees). **Safest choice today, smartest choice tomorrow.**

---

## Scorecard

| Category | Today | 90-day | 6-month |
|----------|-------|--------|---------|
| Data integrity | 6 | 9 | 9.5 |
| Manager scheduling speed | 5 | 8.5 | 9.5 |
| Smart Suggestions | 1 | 5 | 8.5 |
| Staff experience | 6 | 8 | 9 |
| Payroll trust | 5 | 8 | 9 |
| Deploy reliability | 5 | 9 | 9.5 |
| Billing & self-serve | 2 | 7 | 9 |
| **Overall** | **~5** | **~8.1** | **~9.0** |

Smart Suggestions rubric: **1** none · **3** copy-week + conflicts · **5** manager uses "Suggest Friday" voluntarily 2× · **8** multi-day draft with approval learning

---

## Timeline

| Milestone | Plan | Stretch |
|-----------|------|---------|
| Gate 0 complete | Week 2 | Week 2 |
| Pillar 0 exit | Week 5–6 | Week 4 |
| Smart Suggestions on main | Week 10–11 | Week 9 |
| Strong A-tier (~8.1) | Month 3.5 | Month 3 |
| Customer #2 + billing | Month 5 | Month 4.5 |
| S-tier signals (~9.0) | Month 8 | Month 7 |

Communicate **5–6 months** internally for strong A-tier.

---

## Gate 0 — Stabilize (Weeks 1–2)

See [GATE0.md](GATE0.md).

**Exit:** 7 P0-free days · [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md) filled · CI green

---

## Pillar 0 — Foundation (Weeks 2–6)

**After Gate 0 exit only.**

| Item | Detail |
|------|--------|
| Calendar refactor | Strangler split of `calendar_page.dart` → 4 modules ([plan](pillar0/CALENDAR_MODULE_MAP.md)) |
| user_id migration | Backfill script; reduce name-based `staff` references |
| Migrations in Git | Vendor SQL from [inventory](pillar0/MIGRATION_INVENTORY.md) into `supabase/migrations/` |
| Sentry | Error monitoring web + mobile |
| E2E smoke | CI path: auth → publish → swap → clock → CSV ([spec](pillar0/E2E_SMOKE_SPEC.md)) |
| Analytics events | `schedule_create_start/end`, `publish_success/fail`, `staff_open` |

**Exit:** 21 consecutive clean days at Jigsy's · no dev rescue

---

## Pillar A — Speed + Smart Suggestions (Weeks 6–11)

| Item | Detail |
|------|--------|
| TIMESTAMPTZ + org timezone | Bars crossing midnight |
| Templates + copy week + bulk edit | Primary manager ROI |
| Conflict detection | Double-book, availability, OT warning |
| Draft → summary → publish | Human-readable review before live |
| Smart Suggestions v0.5 | Rules 80% + LLM summary only ([spike](pillar0/SMART_SUGGESTIONS_SPIKE.md)) |
| Drag-and-drop | Stretch if refactor allows |

**Exit:** Schedule time ↓40–50% vs baseline · blind WIW speed test

---

## Pillar B — Staff Trust (Weeks 11–14)

- Push hardening
- Offline read cache (this week only)
- Fairness panel (hours, weekends, OT)
- Optional 3-emoji post-shift pulse — **kill if &lt;20% response after 4 weeks**

**Exit:** Staff WAU &gt;80% · swap median &lt;24h

---

## Pillar C — Payroll Trust (Weeks 14–18)

- Geofenced clock-in + manager override
- Break + OT flags · basic PTO
- Timesheet approval → CSV + one payroll format (QuickBooks **or** ADP)

**Exit:** Owner signs off real payroll run without re-keying

---

## Pillar D — Monetize (Weeks 18–22)

- `billingEnabled = true` when customer #2 warm lead commits (LOI OK)
- Stripe + self-serve onboarding + CSV staff import
- Dashboard v1: labor % vs budget, coverage gaps (manual sales first)

**Exit:** Customer #2 paying or pilot-with-check

---

## Pillar E — Moat (Month 6+)

- Multi-day AI drafts with approval learning
- WIW / 7shifts import
- POS CSV paths (Square, Toast)
- Multi-location polish · predictive understaffing alerts

---

## Kill list (locked)

Team chat · shift bidding marketplace · voice input · heavy gamification · separate React dashboard · SOC2 · Zapier until customer #5 · full autonomous AI before Smart Suggestions v0.5 proves value

---

## Key files

| Path | Role |
|------|------|
| `lib/calendar_page.dart` | Main UI (~2000 lines — refactor target) |
| `lib/auth_page.dart` | Signup / invite flow |
| `lib/core/profile_service.dart` | Org ID, `apex_redeem_invite` |
| `lib/core/app_config.dart` | `billingEnabled = false` |
| `scripts/build_web.sh` | Vercel build |
| `docs/VERCEL.md` | Deploy troubleshooting |

---

## 90-day targets (from baseline)

| Metric | Target |
|--------|--------|
| Schedule build time | ↓50% |
| Publish failures / month | 0 |
| Staff weekly engagement | &gt;80% (after analytics) |
| Swap resolution | &lt;24h median |
| Payroll re-key | ~0 min |
| Manager score vs spreadsheet | ≥8/10 |

Baseline source: [JIGSYS_BASELINE.md](JIGSYS_BASELINE.md)
