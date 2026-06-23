#!/usr/bin/env bash
# Quick API smoke checks against home server (run from laptop or phone network).
# Usage: ./scripts/smoke-check-home-api.sh

set -euo pipefail

BASE="${API_BASE_URL:-http://andex.1rmx.ru:40080/api}"
ORIGIN="${BASE%/api}"

http_code() {
  local url="$1"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || true)
  if [[ -z "$code" || "$code" == "000" ]]; then
    echo "000"
  else
    echo "$code"
  fi
}

echo "==> Checking $BASE"

code_me=$(http_code "$BASE/users/me")
echo "GET /users/me (no auth): HTTP $code_me (expect 401 when server is up)"

code_map=$(http_code "$BASE/users/map?minLat=55&maxLat=56&minLon=37&maxLon=38")
echo "GET /users/map (no auth): HTTP $code_map (expect 401 when server is up)"

if curl -s --connect-timeout 5 --max-time 10 "$ORIGIN/" >/dev/null 2>&1; then
  echo "Origin $ORIGIN reachable"
else
  echo "Origin $ORIGIN not reachable — deploy backend or check port forward"
fi

echo ""
echo "After deploy + seeds, verify on phone:"
echo "  1. Firebase login"
echo "  2. Location sync PUT /users/me/location ~30s"
echo "  3. Map: events + users"
echo "  4. Tap user marker -> profile"
echo "  5. Matches + My likes tabs"
echo "  6. Privacy -> women only filter"
echo "  7. Event GOING -> self check-in"
echo "  8. Organizer manage: check-in, kick, waitlist"
