# Pillar 0 — E2E smoke test spec

**Goal:** One automated path that proves critical flows work on every PR touching calendar/auth.

**Gate 0:** Spec only (this doc). **Pillar 0:** Implement with `integration_test` package.

---

## Smoke path (happy path)

```
1. AUTH     Sign in as owner test account
2. PUBLISH  Create shift for tomorrow → Publish Shifts Live → success banner
3. STAFF    Sign in as staff → shift visible on calendar
4. SWAP     Staff request swap → owner approve → status updated
5. CLOCK    Staff clock in → clock out → entry persisted
6. CSV      Owner export time card CSV → non-empty, expected columns
```

---

## Test accounts (Supabase)

Create dedicated E2E org — **not Jigsy's production org.**

| Role | Email pattern | Notes |
|------|---------------|-------|
| Owner | `e2e-owner+<run>@…` | org admin |
| Staff | `e2e-staff+<run>@…` | invite or seed |

Store credentials in GitHub Actions secrets: `E2E_OWNER_EMAIL`, `E2E_OWNER_PASSWORD`, etc.

---

## Implementation plan

### Package

Add to `pubspec.yaml` dev:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

### File layout

```
integration_test/
  smoke_test.dart      # full path above
  support/
    test_config.dart   # SUPABASE_URL, keys from --dart-define
    auth_helpers.dart
```

### CI job (add to `.github/workflows/ci.yml` after Pillar 0)

Optional second job `e2e-web` on `ubuntu-latest`:

- Build web with test dart-defines
- Run `flutter test integration_test/smoke_test.dart -d web-server`

Start with **local/manual** smoke checklist during Gate 0; automate in Pillar 0 week 1.

---

## Manual Gate 0 checklist (until automated)

Run on each production deploy:

- [ ] Owner login (incognito)
- [ ] Publish one test shift → green banner
- [ ] Staff login → shift visible
- [ ] Create swap → owner approve → both see update
- [ ] Clock in/out
- [ ] CSV download opens with rows

Log result in [JIGSYS_BASELINE.md](../JIGSYS_BASELINE.md) daily notes if tested.

---

## P0 failure mapping

| Step | P0 if |
|------|-------|
| Publish | Error toast, silent fail, white screen |
| Staff view | Shift not visible within 60s (Realtime) |
| Swap | Approval not persisting |
| CSV | Empty file or corrupt |

---

## Non-goals (smoke v1)

- Billing / Stripe
- Push delivery (manual push test in baseline)
- Multi-day batch publish edge cases
- Offline mode
