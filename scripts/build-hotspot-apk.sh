#!/usr/bin/env bash
# Release APK when the phone shares internet (personal hotspot).
# 1. Enable hotspot on the phone.
# 2. Connect the Mac to that Wi‑Fi network.
# 3. Start Docker/API on the Mac (Traefik :80).
# 4. Run: ./scripts/build-hotspot-apk.sh
#
# Override IP if auto-detect fails:
#   HOTSPOT_IP=10.85.79.160 ./scripts/build-hotspot-apk.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_NAME="${1:-andexevents-2.1-hotspot}"
NSC_FILE="$ROOT/android/app/src/main/res/xml/network_security_config.xml"

detect_hotspot_ip() {
  local iface ip
  for iface in en0 en1 bridge100; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -z "$ip" ]]; then
      continue
    fi
    if [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.20\.10\. ]]; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

ensure_cleartext_ip() {
  local ip="$1"
  if grep -q ">${ip}<" "$NSC_FILE"; then
    return 0
  fi
  python3 - "$NSC_FILE" "$ip" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
ip = sys.argv[2]
text = path.read_text(encoding="utf-8")
needle = "    </domain-config>"
insert = (
    f'        <!-- Hotspot build ({ip}) -->\n'
    f'        <domain includeSubdomains="false">{ip}</domain>\n'
)
if insert.strip() in text:
    raise SystemExit(0)
if needle not in text:
    raise SystemExit("network_security_config.xml: closing </domain-config> not found")
path.write_text(text.replace(needle, insert + needle, 1), encoding="utf-8")
PY
}

HOTSPOT_IP="${HOTSPOT_IP:-}"
if [[ -z "$HOTSPOT_IP" ]]; then
  HOTSPOT_IP="$(detect_hotspot_ip || true)"
fi

if [[ -z "$HOTSPOT_IP" ]]; then
  echo "Не найден IP раздачи (10.* или 172.20.10.*)."
  echo "Подключи Mac к Wi‑Fi раздаче телефона и повтори."
  echo "Или укажи вручную: HOTSPOT_IP=10.x.x.x $0"
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-http://${HOTSPOT_IP}/api}"
ensure_cleartext_ip "$HOTSPOT_IP"

echo "Hotspot IP: $HOTSPOT_IP"
echo "API: $API_BASE_URL"

MAP_KEY_FILE="$ROOT/secrets/yandex_mapkit_api_key.txt"
GEO_KEY_FILE="$ROOT/secrets/yandex_geocode_api_key.txt"

if [[ ! -f "$MAP_KEY_FILE" || ! -f "$GEO_KEY_FILE" ]]; then
  echo "Missing secrets in $ROOT/secrets/"
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
echo ""
echo "Готово. Установи APK на телефон (тот же hotspot, API на Mac)."
echo "API вшит: $API_BASE_URL"
