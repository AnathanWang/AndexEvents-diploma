#!/usr/bin/env bash
# Поднимает весь Docker-стенд из одного compose-файла (без конфликта сетей).
# Usage: ./scripts/docker-up.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/deployments/docker/docker-compose.yml"
COMPOSE_PROJECT="andexevents"

echo "==> Останавливаем старые контейнеры (root + deployments)..."
docker compose -f "$ROOT/docker-compose.yml" down --remove-orphans 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" -p docker down --remove-orphans 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT" down --remove-orphans 2>/dev/null || true

echo "==> Запуск полного стека..."
docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT" up -d --build

echo "==> Ожидание Postgres..."
for i in $(seq 1 60); do
  if docker exec andexevents-postgres pg_isready -U andexevents -d andexevents -q 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "==> Ожидание Java-сервисов (~20s)..."
sleep 20

echo "==> Проверка health..."
curl -sf http://localhost:8081/health >/dev/null && echo "  users-service: OK" || echo "  users-service: FAIL"
curl -sf http://localhost:8082/health >/dev/null && echo "  events-service: OK" || echo "  events-service: FAIL"
curl -sf http://localhost:8005/health >/dev/null && echo "  match-service: OK" || echo "  match-service: FAIL"
curl -sf http://localhost:8006/health >/dev/null && echo "  upload-service: OK" || echo "  upload-service: FAIL"
curl -sf http://localhost/api/events >/dev/null && echo "  traefik /api/events: OK" || echo "  traefik /api/events: FAIL"

echo ""
echo "Готово. API: http://localhost/api"
echo "pgAdmin: localhost:5433, user andexevents"
echo ""
echo "Flutter (симулятор):  flutter run"
echo "Flutter (телефон):    flutter run --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0 2>/dev/null || echo 'YOUR_IP')/api"
