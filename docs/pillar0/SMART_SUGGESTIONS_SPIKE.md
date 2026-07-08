# Pillar 0 — Smart Suggestions spike (branch-only)

**Product name:** Smart Suggestions (not "AI Assistant")  
**Gate 0:** Read-only spike on branch — **no merge to main**  
**Pillar A:** Merge after templates + conflicts stable

---

## Scope (v0.5 target)

**Input:** Manager text or preset — e.g. "Staff Friday like last Friday but +1 barback"

**Output:** Proposed shift diff → Accept All / Edit / Reject — **never auto-publish**

---

## Spike deliverable (Gate 0 branch)

Script or Edge Function stub that:

1. Reads last 4 weeks of `shifts` for `organization_id`
2. Filters to target date's day-of-week
3. Applies heuristics:
   - Same roles/titles as median of last 4 matching weekdays
   - Exclude staff marked unavailable
   - Flag conflicts (double-book, OT &gt; threshold)
4. Returns JSON:

```json
{
  "suggestions": [
    { "action": "add", "shift_date": "2026-07-11", "title": "Bar", "staff": "Open", "notes": "Shift: 5:00 PM - 11:00 PM" }
  ],
  "warnings": ["Alex already scheduled 6 days this week"],
  "summary": "Friday staffed like 2026-07-04 with one extra barback."
}
```

**LLM (spike optional):** Rewrite `summary` only — do not let model invent shifts.

---

## Stack options

| Layer | Option |
|-------|--------|
| Rules | Dart service or Supabase Edge Function (TypeScript) |
| LLM polish | Edge Function + Grok/OpenAI, gated by env secret |
| Cost | LLM on "Generate summary" tap only |

---

## Success metric (Pillar A)

Manager uses Smart Suggestions **voluntarily ≥2 times** at Jigsy's and accepts ≥1 suggestion.

---

## Files (when implemented)

```
lib/features/smart_suggestions/
  suggestion_engine.dart      # rules only
  suggestion_models.dart
supabase/functions/suggest-shifts/index.ts   # optional server-side
```

---

## Out of scope for spike

- Learning from approvals
- Multi-day auto-draft
- Sales data integration
- UI beyond debug print / CLI
