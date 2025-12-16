#!/bin/sh
# store_yandex_key.sh
#
# Usage:
#   ./scripts/store_yandex_key.sh <YANDEX_MAPKIT_API_KEY> [YANDEX_GEOCODE_API_KEY]
#
# If the optional second parameter is provided, the script will also store the
# Yandex Geocoding API key for local backend usage (backend/.env and secrets/).
#
# What this script does (safe, local-only):
#  - Writes the provided Yandex MapKit API key into several local files that are git-ignored:
#      - android/local.properties   (adds/updates YANDEX_MAPKIT_API_KEY)
#      - ios/Secrets.xcconfig       (creates/overwrites with YANDEX_MAPKIT_API_KEY)
#      - secrets/yandex_mapkit_api_key.txt (creates a small file with restricted permissions)
#  - Optionally writes the Geocoding API key:
#      - backend/.env               (adds/updates YANDEX_MAPS_API_KEY)
#      - secrets/yandex_geocode_api_key.txt
#  - Does NOT commit, push, or alter git history.
#  - Intended to be run locally by a developer or in a protected environment.
#
# Security notes:
#  - These files should be in .gitignore (this repo already includes a `secrets/` ignore).
#  - Do NOT copy these files into build artifacts, logs, or public places.
#  - To use keys in CI, add them to the CI's secret storage and avoid printing them in logs.
#
# Exit codes:
#  0 - success
#  1 - usage / missing argument
#  2 - unexpected filesystem error

set -eu

print_usage() {
  echo "Usage: $0 <YANDEX_MAPKIT_API_KEY> [YANDEX_GEOCODE_API_KEY] [SUPABASE_ANON_KEY]"
  echo
  echo "Examples:"
  echo "  $0 e1866e10-6591-46c9-97b9-fbe8ad56a2f6"
  echo "  $0 e1866e10-6591-46c9-97b9-fbe8ad56a2f6 abcd1234-geocode-key"
  echo "  $0 e1866e10-6591-46c9-97b9-fbe8ad56a2f6 abcd1234-geocode-key supabase-anon-key"
}

# Check arguments (accept 1..3 args)
if [ $# -lt 1 ] || [ $# -gt 3 ]; then
  print_usage
  exit 1
fi

YANDEX_KEY="$1"
GEOCODE_KEY="${2:-}"
SUPABASE_KEY="${3:-}"

# Basic validation: ensure looks like a key-ish string (loose check)
if echo "$YANDEX_KEY" | grep -Eq '^[A-Za-z0-9-]{8,}$'; then
  :
else
  echo "Warning: provided MapKit key doesn't look like a common API key. Proceeding anyway."
fi

if [ -n "$GEOCODE_KEY" ]; then
  if echo "$GEOCODE_KEY" | grep -Eq '^[A-Za-z0-9-]{8,}$'; then
    :
  else
    echo "Warning: provided Geocode key looks unusual. Proceeding anyway."
  fi
fi

if [ -n "$SUPABASE_KEY" ]; then
  if echo "$SUPABASE_KEY" | grep -Eq '^[A-Za-z0-9-_.=]{8,}$'; then
    :
  else
    echo "Warning: provided Supabase anon key looks unusual. Proceeding anyway."
  fi
fi

# Compute project root (assume script is in scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Helper: safe temp file
mktemp_safe() {
  tmp="$(mktemp 2>/dev/null || printf '%s' "/tmp/tmp.$$")"
  printf '%s' "$tmp"
}

# ---------- Android: update android/local.properties ----------
ANDROID_LOCAL_PROPERTIES="$PROJECT_ROOT/android/local.properties"
echo "Writing Android local properties -> $ANDROID_LOCAL_PROPERTIES"

# Ensure android dir exists
if [ ! -d "$PROJECT_ROOT/android" ]; then
  echo "Creating android/ directory"
  mkdir -p "$PROJECT_ROOT/android"
fi

# Create file if missing
if [ ! -f "$ANDROID_LOCAL_PROPERTIES" ]; then
  touch "$ANDROID_LOCAL_PROPERTIES"
  chmod 600 "$ANDROID_LOCAL_PROPERTIES" || true
fi

# Remove any existing YANDEX_MAPKIT_API_KEY lines (safe rewrite)
TMP="$(mktemp_safe)"
if grep -qE '^YANDEX_MAPKIT_API_KEY=' "$ANDROID_LOCAL_PROPERTIES" 2>/dev/null; then
  grep -vE '^YANDEX_MAPKIT_API_KEY=' "$ANDROID_LOCAL_PROPERTIES" > "$TMP" || true
else
  # copy original content to tmp to preserve existing properties
  cat "$ANDROID_LOCAL_PROPERTIES" > "$TMP" || true
fi

# Append our key with a comment
{
  echo ""
  echo "# Local Yandex MapKit API key (do NOT commit)"
  printf 'YANDEX_MAPKIT_API_KEY=%s\n' "$YANDEX_KEY"
} >> "$TMP"

# Move back atomically
mv "$TMP" "$ANDROID_LOCAL_PROPERTIES"
chmod 600 "$ANDROID_LOCAL_PROPERTIES" || true

echo "Android local.properties updated."

# ---------- iOS: create ios/Secrets.xcconfig ----------
IOS_XCCONFIG="$PROJECT_ROOT/ios/Secrets.xcconfig"
echo "Writing iOS xcconfig -> $IOS_XCCONFIG"

if [ ! -d "$PROJECT_ROOT/ios" ]; then
  echo "Creating ios/ directory"
  mkdir -p "$PROJECT_ROOT/ios"
fi

cat > "$IOS_XCCONFIG" <<EOF
// Local secrets for iOS builds (do NOT commit)
YANDEX_MAPKIT_API_KEY = $YANDEX_KEY
EOF

chmod 600 "$IOS_XCCONFIG" || true
echo "iOS Secrets.xcconfig created."

# ---------- secrets/: store small files (git-ignored) ----------
SECRETS_DIR="$PROJECT_ROOT/secrets"
mkdir -p "$SECRETS_DIR"
YAND_EX_FILE="$SECRETS_DIR/yandex_mapkit_api_key.txt"

printf '%s' "$YANDEX_KEY" > "$YAND_EX_FILE"
chmod 600 "$YAND_EX_FILE" || true

echo "Stored MapKit key in: $YAND_EX_FILE (permissions set to 600)."

# ---------- Optional: Geocoding key handling ----------
if [ -n "$GEOCODE_KEY" ]; then
  echo "Storing Geocoding key locally..."

  # 1) secrets file
  YANDEX_GEOCODE_FILE="$SECRETS_DIR/yandex_geocode_api_key.txt"
  printf '%s' "$GEOCODE_KEY" > "$YANDEX_GEOCODE_FILE"
  chmod 600 "$YANDEX_GEOCODE_FILE" || true
  echo "Stored geocode key in: $YANDEX_GEOCODE_FILE (permissions set to 600)."

  # 2) backend/.env (create or update)
  BACKEND_ENV="$PROJECT_ROOT/backend/.env"
  if [ ! -d "$PROJECT_ROOT/backend" ]; then
    echo "Creating backend/ directory"
    mkdir -p "$PROJECT_ROOT/backend"
  fi

  if [ ! -f "$BACKEND_ENV" ]; then
    touch "$BACKEND_ENV"
    chmod 600 "$BACKEND_ENV" || true
  fi

  TMP_ENV="$(mktemp_safe)"
  if grep -qE '^YANDEX_MAPS_API_KEY=' "$BACKEND_ENV" 2>/dev/null; then
    grep -vE '^YANDEX_MAPS_API_KEY=' "$BACKEND_ENV" > "$TMP_ENV" || true
  else
    cat "$BACKEND_ENV" > "$TMP_ENV" || true
  fi

  {
    echo ""
    echo "# Local Yandex Geocoding API key (do NOT commit)"
    printf 'YANDEX_MAPS_API_KEY=%s\n' "$GEOCODE_KEY"
  } >> "$TMP_ENV"

  mv "$TMP_ENV" "$BACKEND_ENV"
  chmod 600 "$BACKEND_ENV" || true

  echo "backend/.env updated with YANDEX_MAPS_API_KEY (do NOT commit this file)."
fi

# ---------- Optional: Supabase anon key handling ----------
if [ -n "$SUPABASE_KEY" ]; then
  echo "Storing Supabase anon key locally..."

  # Ensure secrets dir exists (already created above)
  SUPABASE_FILE="$SECRETS_DIR/supabase_anon_key.txt"
  printf '%s' "$SUPABASE_KEY" > "$SUPABASE_FILE"
  chmod 600 "$SUPABASE_FILE" || true
  echo "Stored Supabase anon key in: $SUPABASE_FILE (permissions set to 600)."

  # Optionally add to ios/Secrets.xcconfig to make it available for iOS simulator builds
  IOS_XCCONFIG="$PROJECT_ROOT/ios/Secrets.xcconfig"
  if [ -f "$IOS_XCCONFIG" ]; then
    # Remove existing SUPABASE_ANON_KEY lines if present
    if grep -qE '^SUPABASE_ANON_KEY' "$IOS_XCCONFIG" 2>/dev/null; then
      TMP_SC="$(mktemp_safe)"
      grep -vE '^SUPABASE_ANON_KEY' "$IOS_XCCONFIG" > "$TMP_SC" || true
      mv "$TMP_SC" "$IOS_XCCONFIG"
    fi
    # Append the key
    printf '\n# Local Supabase anon key\nSUPABASE_ANON_KEY = %s\n' "$SUPABASE_KEY" >> "$IOS_XCCONFIG"
    chmod 600 "$IOS_XCCONFIG" || true
    echo "iOS Secrets.xcconfig updated with SUPABASE_ANON_KEY (do NOT commit)."
  else
    echo "Note: $IOS_XCCONFIG not found. If you want SUPABASE_ANON_KEY available for iOS builds, create ios/Secrets.xcconfig and re-run the script."
  fi

  # Note: For Flutter/Dart usage, pass via --dart-define:
  echo "To use the Supabase key in Flutter/Dart, run:"
  echo "  flutter run --dart-define=SUPABASE_ANON_KEY=\$(cat $SUPABASE_FILE)"

fi

# 4) Reminder and usage hints
echo
echo "IMPORTANT:"
echo " - These files are local and should NOT be committed. Verify .gitignore includes 'secrets/' and/or the files you created."
echo " - For Android builds, local.properties will be read by the Gradle manifestPlaceholder (project must be configured)."
echo " - For iOS, include Secrets.xcconfig in your Xcode build settings or use it via an xcconfig include."
echo " - For backend development, the geocoding key was written to backend/.env; restart your backend to pick it up."
echo
echo "How to use for Flutter builds locally (examples):"
echo "  flutter run --dart-define=YANDEX_MAPKIT_API_KEY=\$(cat secrets/yandex_mapkit_api_key.txt)"
echo "  flutter run --dart-define=YANDEX_API_KEY=\$(cat secrets/yandex_geocode_api_key.txt)"
echo
echo "Or add to CI as secrets and pass them during the build."
echo
echo "If you want this script to also configure your Gradle / Xcode project files automatically,"
echo "tell me and I can provide step-by-step commands to wire the placeholders into the builds."
echo
echo "Done."
exit 0
