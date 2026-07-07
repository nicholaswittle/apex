#!/usr/bin/env bash
# Build Flutter web for Vercel (or local preview).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Install Flutter on CI/Vercel when not present
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
  if [[ ! -d "$FLUTTER_DIR/bin" ]]; then
    echo "==> Installing Flutter stable..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter config --enable-web
flutter pub get

# Load local env for dev builds
if [[ -f "$ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
fi

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

DEFINES=()
if [[ -n "$SUPABASE_URL" ]]; then
  DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
fi
if [[ -n "$SUPABASE_ANON_KEY" ]]; then
  DEFINES+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi

echo "==> Building Flutter web (release)..."
flutter build web --release --no-wasm-dry-run --pwa-strategy=none "${DEFINES[@]}"

echo "==> Output: $ROOT/build/web"
