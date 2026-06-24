#!/usr/bin/env bash
# Release APK for physical phone.
# Default: Mac Docker API on LAN (auto-detected IP).
# Home server: API_BASE_URL=http://andex.1rmx.ru:40080/api ./scripts/build-home-server-apk.sh
# Usage: ./scripts/build-home-server-apk.sh [output_name]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_NAME="${1:-andexevents-demo}"
MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "192.168.1.147")"
API_BASE_URL="${API_BASE_URL:-http://${MAC_IP}/api}"

MAP_KEY_FILE="$ROOT/secrets/yandex_mapkit_api_key.txt"
GEO_KEY_FILE="$ROOT/secrets/yandex_geocode_api_key.txt"

if [[ ! -f "$MAP_KEY_FILE" ]]; then
  echo "Missing $MAP_KEY_FILE"
  exit 1
fi

if [[ ! -f "$GEO_KEY_FILE" ]]; then
  echo "Missing $GEO_KEY_FILE"
  exit 1
fi

cd "$ROOT"
flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=YANDEX_MAPKIT_API_KEY="$(cat "$MAP_KEY_FILE")" \
  --dart-define=YANDEX_API_KEY="$(cat "$GEO_KEY_FILE")" \
  --dart-define=YANDEX_MAPS_API_KEY="$(cat "$MAP_KEY_FILE")"

cp build/app/outputs/flutter-apk/app-release.apk \
  "build/app/outputs/flutter-apk/${OUT_NAME}.apk"

ls -lh "build/app/outputs/flutter-apk/${OUT_NAME}.apk"
echo "API baked in: $API_BASE_URL"
