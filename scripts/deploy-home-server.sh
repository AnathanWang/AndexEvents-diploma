#!/usr/bin/env bash
# Deploy AndexEvents to home server via docker-compose.prod.yml
# Usage (on server, from repo root):
#   cp .env.example .env   # fill secrets first
#   ./scripts/deploy-home-server.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.prod.yml"

cd "$ROOT"

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Missing .env — copy .env.example and set POSTGRES_PASSWORD, MINIO_*, FIREBASE_PROJECT_ID, UPLOADS_PUBLIC_BASE_URL"
  exit 1
fi

if [[ ! -f "$ROOT/secrets/firebase-service-account.json" ]]; then
  echo "Missing secrets/firebase-service-account.json"
  exit 1
fi

echo "==> Building images..."
docker compose -f "$COMPOSE_FILE" build

echo "==> Starting stack..."
docker compose -f "$COMPOSE_FILE" up -d

echo "==> Waiting for services (~30s)..."
sleep 30

echo "==> Container status:"
docker compose -f "$COMPOSE_FILE" ps

echo "==> Seeding demo data..."
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_fake_match_profiles.sql" || true
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_demo_events.sql" || true
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_demo_participants.sql" || true

echo ""
echo "==> Smoke check (expect 401 without token):"
curl -s -o /dev/null -w "GET /api/users/me -> HTTP %{http_code}\n" \
  "http://andex.1rmx.ru:40080/api/users/me" || echo "curl failed — check port forward / Traefik"

echo ""
echo "Done. Build APK: ./scripts/build-home-server-apk.sh andexevents-demo"
