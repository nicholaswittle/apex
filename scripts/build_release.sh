#!/usr/bin/env bash
# Apex Scheduler — release build helper for M1 Mac / CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
fi

DART_DEFINES=()
add_define() {
  local key="$1"
  local val="${!key:-}"
  if [[ -n "$val" ]]; then
    DART_DEFINES+=("--dart-define=${key}=${val}")
  fi
}

for key in SUPABASE_URL SUPABASE_ANON_KEY STRIPE_PUBLISHABLE_KEY; do
  add_define "$key"
done

flutter pub get

TARGET="${1:-all}"

build_ios() {
  echo "==> iOS release compile (no codesign)"
  flutter build ios --release --no-codesign "${DART_DEFINES[@]}"
}

build_android() {
  echo "==> Android App Bundle"
  flutter build appbundle --release "${DART_DEFINES[@]}"
}

case "$TARGET" in
  ios) build_ios ;;
  android) build_android ;;
  all)
    build_ios
    build_android
    ;;
  *)
    echo "Usage: $0 [ios|android|all]"
    exit 1
    ;;
esac

echo "==> Done"
