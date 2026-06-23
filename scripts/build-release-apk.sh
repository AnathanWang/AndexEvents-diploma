#!/usr/bin/env bash
# Release APK for a physical phone against local Docker API.
# Usage: ./scripts/build-release-apk.sh [output_name]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_NAME="${1:-andexevents04}"
API_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "192.168.1.146")"

MAP_KEY_FILE="$ROOT/secrets/yandex_mapkit_api_key.txt"
GEO_KEY_FILE="$ROOT/secrets/yandex_geocode_api_key.txt"

if [[ ! -f "$MAP_KEY_FILE" ]]; then
  echo "Missing $MAP_KEY_FILE"
  exit 1
fi

cd "$ROOT"
flutter build apk --release \
  --dart-define=API_BASE_URL="http://${API_IP}/api" \
  --dart-define=YANDEX_MAPKIT_API_KEY="$(cat "$MAP_KEY_FILE")" \
  --dart-define=YANDEX_API_KEY="$(cat "$GEO_KEY_FILE")" \
  --dart-define=YANDEX_MAPS_API_KEY="$(cat "$MAP_KEY_FILE")"

cp build/app/outputs/flutter-apk/app-release.apk \
  "build/app/outputs/flutter-apk/${OUT_NAME}.apk"

ls -lh "build/app/outputs/flutter-apk/${OUT_NAME}.apk"
echo "API baked in: http://${API_IP}/api"
