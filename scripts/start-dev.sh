#!/usr/bin/env bash
#
# start-dev.sh
#
# Helper to wire local secrets (MapKit, Geocoding, Supabase anon) and start
# backend (dev) and Flutter app for local development.
#
# Usage:
#   ./scripts/start-dev.sh [MAPKIT_KEY] [GEOCODE_KEY] [SUPABASE_ANON_KEY]
#
# Behavior:
# - If keys are provided as positional args, the script will store them locally
#   (via scripts/store_yandex_key.sh if available) into git-ignored files.
# - If args are not provided, the script will attempt to read keys from:
#     secrets/yandex_mapkit_api_key.txt
#     secrets/yandex_geocode_api_key.txt
#     secrets/supabase_anon_key.txt
#   and backend/.env (for geocode).
# - Exports environment variables needed by Gradle/Flutter/backend.
# - Starts backend (npm run dev) in background and then runs `flutter run`.
# - Cleans up background backend process on exit.
#
# IMPORTANT:
# - This script writes secrets to local files which are ignored by git.
# - Do NOT commit the generated files. Treat them as sensitive.
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
SECRETS_DIR="$ROOT_DIR/secrets"
BACKEND_DIR="$ROOT_DIR/backend"

# Arguments
MAPKIT_ARG="${1:-}"
GEOCODE_ARG="${2:-}"
SUPABASE_ARG="${3:-}"

# Ensure secrets dir exists
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" || true

# Utility: safe write file with 600 perms
_safe_write() {
  local file="$1"
  local content="$2"
  printf '%s' "$content" > "$file"
  chmod 600 "$file" || true
}

# If helper exists, prefer to use it (it centralizes behavior)
if [ -x "$SCRIPTS_DIR/store_yandex_key.sh" ] || [ -f "$SCRIPTS_DIR/store_yandex_key.sh" ]; then
  if [ -n "$MAPKIT_ARG" ] || [ -n "$GEOCODE_ARG" ] || [ -n "$SUPABASE_ARG" ]; then
    echo "Using helper script to persist secrets locally (will not commit files)..."
    # call helper via sh to avoid permission issues
    sh "$SCRIPTS_DIR/store_yandex_key.sh" "$MAPKIT_ARG" "$GEOCODE_ARG" "$SUPABASE_ARG"
  fi
else
  # Fallback: write files directly if args provided
  if [ -n "$MAPKIT_ARG" ]; then
    _safe_write "$SECRETS_DIR/yandex_mapkit_api_key.txt" "$MAPKIT_ARG"
    # also write ios Secrets.xcconfig for simulator usage
    IOS_XCCONFIG="$ROOT_DIR/ios/Secrets.xcconfig"
    printf '%s\n' "// Local secrets for iOS builds (do NOT commit)" > "$IOS_XCCONFIG"
    printf 'YANDEX_MAPKIT_API_KEY = %s\n' "$MAPKIT_ARG" >> "$IOS_XCCONFIG"
    chmod 600 "$IOS_XCCONFIG" || true
    echo "MapKit key written to $SECRETS_DIR/yandex_mapkit_api_key.txt and $IOS_XCCONFIG"
  fi

  if [ -n "$GEOCODE_ARG" ]; then
    _safe_write "$SECRETS_DIR/yandex_geocode_api_key.txt" "$GEOCODE_ARG"
    # ensure backend dir exists and update backend/.env
    mkdir -p "$BACKEND_DIR"
    BACKEND_ENV="$BACKEND_DIR/.env"
    touch "$BACKEND_ENV"
    # replace existing key if present
    if grep -qE '^YANDEX_MAPS_API_KEY=' "$BACKEND_ENV" 2>/dev/null; then
      grep -vE '^YANDEX_MAPS_API_KEY=' "$BACKEND_ENV" > "$BACKEND_ENV.tmp" || true
      mv "$BACKEND_ENV.tmp" "$BACKEND_ENV"
    fi
    printf '\n# Local Yandex Geocoding API key (do NOT commit)\nYANDEX_MAPS_API_KEY=%s\n' "$GEOCODE_ARG" >> "$BACKEND_ENV"
    chmod 600 "$BACKEND_ENV" || true
    echo "Geocode key written to $SECRETS_DIR/yandex_geocode_api_key.txt and $BACKEND_ENV"
  fi

  if [ -n "$SUPABASE_ARG" ]; then
    _safe_write "$SECRETS_DIR/supabase_anon_key.txt" "$SUPABASE_ARG"
    # optionally add to ios xcconfig if it exists
    IOS_XCCONFIG="$ROOT_DIR/ios/Secrets.xcconfig"
    if [ -f "$IOS_XCCONFIG" ]; then
      if ! grep -q '^SUPABASE_ANON_KEY' "$IOS_XCCONFIG" 2>/dev/null; then
        printf '\n# Local Supabase anon key\nSUPABASE_ANON_KEY = %s\n' "$SUPABASE_ARG" >> "$IOS_XCCONFIG"
      fi
    fi
    echo "Supabase anon key saved to $SECRETS_DIR/supabase_anon_key.txt"
  fi
fi

# Read keys from secrets files if present
MAPKIT_KEY=""
GEOCODE_KEY=""
SUPABASE_KEY=""

if [ -f "$SECRETS_DIR/yandex_mapkit_api_key.txt" ]; then
  MAPKIT_KEY="$(cat "$SECRETS_DIR/yandex_mapkit_api_key.txt")"
fi

if [ -f "$SECRETS_DIR/yandex_geocode_api_key.txt" ]; then
  GEOCODE_KEY="$(cat "$SECRETS_DIR/yandex_geocode_api_key.txt")"
fi

if [ -f "$SECRETS_DIR/supabase_anon_key.txt" ]; then
  SUPABASE_KEY="$(cat "$SECRETS_DIR/supabase_anon_key.txt")"
fi

# If backend/.env exists and geocode key not set yet, try to parse it
if [ -z "$GEOCODE_KEY" ] && [ -f "$BACKEND_DIR/.env" ]; then
  if grep -qE '^YANDEX_MAPS_API_KEY=' "$BACKEND_DIR/.env" 2>/dev/null; then
    GEOCODE_KEY="$(grep -E '^YANDEX_MAPS_API_KEY=' "$BACKEND_DIR/.env" | head -n1 | cut -d'=' -f2-)"
  fi
fi

# Export Gradle project property for MapKit (so Android picks it up)
if [ -n "$MAPKIT_KEY" ]; then
  export ORG_GRADLE_PROJECT_YANDEX_MAPKIT_API_KEY="$MAPKIT_KEY"
fi

# Export backend/env vars for current session
if [ -n "$GEOCODE_KEY" ]; then
  export YANDEX_MAPS_API_KEY="$GEOCODE_KEY"
fi
if [ -n "$SUPABASE_KEY" ]; then
  export SUPABASE_ANON_KEY="$SUPABASE_KEY"
fi

echo "Secrets loaded (not printed). Starting backend and Flutter..."

# Start backend (if backend exists)
BACKEND_PID=""
if [ -d "$BACKEND_DIR" ]; then
  # Start backend in background using npm run dev (nodemon/tsx)
  (
    cd "$BACKEND_DIR"
    # Load .env for node process if present
    # Use env variables already exported in this script for immediate use
    npm run dev &
    echo $! > "$BACKEND_DIR/.start-dev-backend.pid"
  )
  # Give it a moment to spawn
  sleep 1
  if [ -f "$BACKEND_DIR/.start-dev-backend.pid" ]; then
    BACKEND_PID="$(cat "$BACKEND_DIR/.start-dev-backend.pid")"
    echo "Backend started (pid: $BACKEND_PID). Waiting for health endpoint..."
  fi

  # Wait for backend health endpoint if available (up to timeout)
  HEALTH_URL="http://localhost:3000/health"
  if command -v curl >/dev/null 2>&1; then
    max_wait=20
    waited=0
    until curl -fsS "$HEALTH_URL" >/dev/null 2>&1 || [ $waited -ge $max_wait ]; do
      printf '.'
      sleep 1
      waited=$((waited + 1))
    done
    if [ $waited -ge $max_wait ]; then
      echo
      echo "Warning: backend health check did not respond within $max_wait seconds. Continuing anyway."
    else
      echo
      echo "Backend is healthy."
    fi
  else
    echo "curl not available — not polling backend health. Continuing..."
  fi
fi

# Setup trap to clean up backend on exit
_cleanup() {
  echo
  echo "Shutting down..."
  if [ -n "$BACKEND_PID" ]; then
    echo "Killing backend pid $BACKEND_PID"
    kill "$BACKEND_PID" 2>/dev/null || true
    rm -f "$BACKEND_DIR/.start-dev-backend.pid" || true
  fi
  exit 0
}
trap _cleanup INT TERM EXIT

# Prepare flutter run args
FLUTTER_ARGS=()

# If SUPABASE_ANON_KEY present, pass it to Dart
if [ -n "$SUPABASE_KEY" ]; then
  FLUTTER_ARGS+=(--dart-define "SUPABASE_ANON_KEY=$SUPABASE_KEY")
fi

# If GEOCODE_KEY present, pass it to Dart as YANDEX_API_KEY
if [ -n "$GEOCODE_KEY" ]; then
  FLUTTER_ARGS+=(--dart-define "YANDEX_API_KEY=$GEOCODE_KEY")
fi

# If MAPKIT_KEY present, pass it to Dart as well (optional)
if [ -n "$MAPKIT_KEY" ]; then
  FLUTTER_ARGS+=(--dart-define "YANDEX_MAPKIT_API_KEY=$MAPKIT_KEY")
fi

# Run flutter (in foreground)
echo "Running: flutter run ${FLUTTER_ARGS[*]}"
# Use exec so that trap on EXIT will run when flutter exits
exec flutter run "${FLUTTER_ARGS[@]}"
