#!/usr/bin/env bash
# Local dev run — copy .env.local.example to .env.local and fill in values.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f "$ROOT/.env.local" ]]; then
  echo "Create .env.local from .env.local.example first."
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/.env.local"

flutter pub get
flutter run \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=STRIPE_PUBLISHABLE_KEY="${STRIPE_PUBLISHABLE_KEY:-}"
