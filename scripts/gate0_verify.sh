#!/usr/bin/env bash
# Gate 0 manual deploy verification — run after Vercel production deploy.
set -euo pipefail

echo "=============================================="
echo "APEX GATE 0 — POST-DEPLOY VERIFICATION"
echo "=============================================="
echo ""
echo "Record commit SHA: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
echo ""
echo "Automated checks:"
if command -v flutter >/dev/null 2>&1; then
  flutter analyze
  flutter test
  echo "✓ flutter analyze + test passed"
else
  echo "⚠ flutter not in PATH — run analyze/test locally or in CI"
fi
echo ""
echo "Manual checks (incognito browser on production URL):"
echo "  [ ] Owner login"
echo "  [ ] Calendar loads"
echo "  [ ] Publish Shifts Live → success banner"
echo "  [ ] Sidework Add → task appears"
echo "  [ ] Swap tab loads"
echo "  [ ] Staff login → sees published shift"
echo "  [ ] CSV export non-empty"
echo ""
echo "Log results in docs/JIGSYS_BASELINE.md"
echo "See docs/GATE0.md for full Gate 0 checklist."
