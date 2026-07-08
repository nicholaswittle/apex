# Pillar 0 — Calendar module map (strangler refactor)

**Target:** Split `lib/calendar_page.dart` (~2000 lines) into focused modules without breaking Jigsy's daily use.

**Rule:** One module extracted per PR. Old code path stays working until parity verified.

---

## Current structure

| Lines (approx) | Symbol | Responsibility |
|----------------|--------|----------------|
| 17–105 | `CalendarPage`, state fields | Shell, tab index, shared state |
| 106–343 | `_load*`, `_change*`, `_handleLogOut` | Data load, navigation, availability |
| 353–394 | `_addNewSideWork` | Sidework CRUD |
| 396–536 | `_handlePostSwap`, `_claim*`, `_processAdminSwapAction` | Swap board logic |
| 537–587 | `_executeDatabaseInsert`, `_submitTimeOffRequest` | Time-off writes |
| 588–679 | `_adminCreateShift`, `_deleteShift` | Publish / delete shifts |
| 681–815 | `_buildSideWorkSection` | Sidework UI |
| 816–931 | `_buildCalendarTab` | Schedule calendar tab |
| 932–1046 | `_buildSwapsTab` | Swaps tab |
| 1047–1206 | `_buildTimeOffTab` | Time-off tab |
| 1207–1448 | `_buildAdminTab` | Admin publish UI |
| 1449–1722 | `build`, tutorial | Scaffold, bottom nav, onboarding |
| 1724–1971 | `_syncDataCore`, vacation helpers | Sync, notifications, multi-day PTO |

---

## Proposed modules

### 1. `lib/features/schedule/schedule_repository.dart`

**Extract:** All Supabase reads/writes for `shifts`, `time_off_requests`.

| Method | Source |
|--------|--------|
| `loadScheduleForDate` | from `_loadScheduleData` / calendar grid data |
| `publishShifts(rows)` | from `_adminCreateShift` insert block |
| `deleteShift(id)` | from `_deleteShift` |
| `loadTimeOffRequests` | from `_loadScheduleData` |

### 2. `lib/features/sidework/sidework_section.dart`

**Extract:** `_addNewSideWork`, `_toggleSideworkCompletion`, `_buildSideWorkSection`.

**State:** `SideWorkController` or callbacks from parent until full Riverpod migration.

### 3. `lib/features/swaps/swap_service.dart` + `swaps_tab.dart`

**Extract:** `_handlePostSwap`, `_claimOpenTemplateShift`, `_claimShift`, `_processAdminSwapAction`, `_buildSwapsTab`.

### 4. `lib/features/admin/admin_publish_panel.dart`

**Extract:** Admin shift form, day selection, `_adminCreateShift` UI half of `_buildAdminTab`.

Keep `LaborCostPanel`, `OrgInvitePanel` as existing widgets.

### 5. `lib/features/time_clock/time_clock_service.dart`

**Extract:** `_loadTimeEntries`, `_clockIn`, `_clockOut`, `_clockedInEntries`.

### 6. `lib/calendar_page.dart` (slim shell)

**Keeps:** Tab scaffold, bottom nav, shared date selection, wires modules together.

**Target size:** &lt;400 lines.

---

## Extraction order (lowest risk first)

1. **Time clock** — isolated, few UI deps  
2. **Sidework section** — self-contained widget + one insert  
3. **Swap service** — clear API boundary  
4. **Schedule repository** — publish/delete (highest P0 risk — test heavily)  
5. **Admin publish panel** — depends on repository  
6. **Time-off tab** — vacation flows last (most entangled)

---

## Per-PR checklist

- [ ] Behavior unchanged (manual test: publish, sidework, swap, clock, CSV)
- [ ] `flutter analyze && flutter test` green
- [ ] No new silent failures — errors surfaced to user
- [ ] Jigsy's smoke on preview deploy before merge

---

## Out of scope for Pillar 0

- Riverpod/Bloc full rewrite (optional incremental)
- TIMESTAMPTZ migration (Pillar A)
- Smart Suggestions (Pillar A, after templates)
