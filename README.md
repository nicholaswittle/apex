# Apex Scheduler

Mobile staff scheduling for **Jigsy's Brewpub** — shifts, swaps, time clock, sidework, and labor cost.

| | |
|--|--|
| **Bundle ID** | `com.wisense.apex` |
| **Stack** | Flutter · Supabase · Firebase Cloud Messaging |
| **Platforms** | iOS · Android · Web |

## Monorepo layout

This app uses a vendored shared UI package:

```
packages/wisense_ui/
projects/apex/apex/    ← this app
```

## Quick start (Mac / Windows / Linux)

```bash
cd projects/apex/apex
cp .env.local.example .env.local   # fill in Supabase keys
flutter pub get
./scripts/run_dev.sh               # mobile/desktop
./scripts/build_web.sh             # web build for Vercel or local preview
```

## Gate 0 & roadmap

**Current phase:** stabilize Jigsy's pilot before new features.

| Doc | Purpose |
|-----|---------|
| **[docs/GATE0.md](docs/GATE0.md)** | Active checklist — merge, 7-day clean run, exit criteria |
| **[docs/JIGSYS_BASELINE.md](docs/JIGSYS_BASELINE.md)** | Baseline metrics (fill with owner by Day 3) |
| **[docs/ROADMAP.md](docs/ROADMAP.md)** | Full plan — Pillars 0–E, timeline, kill list |

## Test on Vercel (web)

See **[docs/VERCEL.md](docs/VERCEL.md)** — deploy the Flutter web build with `SUPABASE_URL` and `SUPABASE_ANON_KEY` env vars.

## Store launch

See **[docs/LAUNCH_CHECKLIST.md](docs/LAUNCH_CHECKLIST.md)** for TestFlight and Play Store steps.

**Don't have a Mac?** See **[docs/LAUNCH_WITHOUT_MAC.md](docs/LAUNCH_WITHOUT_MAC.md)** — Android-first launch path + cloud iOS builds.

Release builds:

```bash
./scripts/build_release.sh ios
./scripts/build_release.sh android
```

## Environment variables

| Variable | Required | Notes |
|----------|----------|-------|
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Public anon key |
| `STRIPE_PUBLISHABLE_KEY` | No | Deferred — billing not enabled for pilot launch |

Pass via `--dart-define` or `scripts/run_dev.sh` / `scripts/build_release.sh`.

## Firebase push

1. Add `ios/Runner/GoogleService-Info.plist` and `android/app/google-services.json` (see `.example` files)
2. `FirebaseBootstrap` initializes on startup; push token sync runs after login

## Diagnostics

From workspace root (Windows):

```powershell
.\scripts\diagnose_apex.ps1
```

On Mac:

```bash
flutter analyze && flutter test
```

## Features

- Shift calendar and availability (full-date scheduling)
- Shift swap board with owner approval and push/in-app notifications
- Sidework checklists with completion tracking
- Time-off requests with approval workflow
- Time clock and CSV export (share sheet on mobile, download on web)
- Organization invite codes for staff onboarding
- Push + in-app notifications for swaps, time off, and schedule updates

> **Billing:** Stripe owner subscriptions are deferred (`AppConfig.billingEnabled = false`). All features are unlocked during the pilot.
