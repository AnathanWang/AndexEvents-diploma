#!/usr/bin/env bash
# Один скрипт для домашнего сервера: Docker + БД + демо-данные.
#
# Отцу:
#   1. git clone https://github.com/AnathanWang/AndexEvents-diploma.git && cd AndexEvents-diploma
#   2. Положить firebase-service-account.json в secrets/
#   3. cp deploy/env.template .env   # заполнить 4 поля
#   4. ./scripts/setup-home-server.sh
#
# На роутере: внешний :8081 → IP_сервера:80

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.prod.yml"

cd "$ROOT"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Не найдено: $1. Установи Docker и Docker Compose."
    exit 1
  fi
}

need_cmd docker
if ! docker compose version >/dev/null 2>&1; then
  echo "Нужен Docker Compose v2 (команда: docker compose)"
  exit 1
fi

if [[ ! -f "$ROOT/.env" ]]; then
  if [[ -f "$ROOT/deploy/env.template" ]]; then
    cp "$ROOT/deploy/env.template" "$ROOT/.env"
    echo "Создан .env из шаблона. Заполни пароли, FIREBASE_PROJECT_ID и PUBLIC_URL, затем запусти снова."
    exit 1
  fi
  echo "Нет файла .env — скопируй deploy/env.template в .env"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "$ROOT/.env"
set +a

if [[ -z "${POSTGRES_PASSWORD:-}" || "${POSTGRES_PASSWORD}" == "ПРИДУМАЙ_ПАРОЛЬ" ]]; then
  echo "Заполни POSTGRES_PASSWORD в .env"
  exit 1
fi
if [[ -z "${MINIO_ROOT_PASSWORD:-}" || "${MINIO_ROOT_PASSWORD}" == "ПРИДУМАЙ_ПАРОЛЬ" ]]; then
  echo "Заполни MINIO_ROOT_PASSWORD в .env"
  exit 1
fi
if [[ -z "${FIREBASE_PROJECT_ID:-}" || "${FIREBASE_PROJECT_ID}" == "твой-firebase-project-id" ]]; then
  echo "Заполни FIREBASE_PROJECT_ID в .env"
  exit 1
fi
if [[ -z "${PUBLIC_URL:-}" ]]; then
  echo "Заполни PUBLIC_URL в .env (например http://85.93.42.123:8081)"
  exit 1
fi

export UPLOADS_PUBLIC_BASE_URL="${PUBLIC_URL}"

if [[ ! -f "$ROOT/secrets/firebase-service-account.json" ]]; then
  echo "Положи secrets/firebase-service-account.json и запусти снова."
  exit 1
fi

apply_sql() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Пропуск (нет файла): $file"
    return 0
  fi
  echo "==> SQL: $(basename "$file")"
  docker exec -i andexevents-postgres psql -U "${POSTGRES_USER:-andexevents}" -d "${POSTGRES_DB:-andexevents}" <"$file"
}

wait_postgres() {
  echo "==> Ждём Postgres..."
  for _ in $(seq 1 60); do
    if docker exec andexevents-postgres pg_isready -U "${POSTGRES_USER:-andexevents}" -d "${POSTGRES_DB:-andexevents}" -q 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "Postgres не поднялся за 2 минуты"
  exit 1
}

echo "==> Сборка и запуск Docker..."
docker compose -f "$COMPOSE_FILE" up -d --build

wait_postgres
sleep 5

echo "==> База и демо-данные..."
apply_sql "$ROOT/deployments/docker/postgres-init/01-match-table.sql"
apply_sql "$ROOT/scripts/seed_fake_match_profiles.sql"
apply_sql "$ROOT/scripts/seed_demo_events.sql"
apply_sql "$ROOT/scripts/seed_demo_participants.sql"
apply_sql "$ROOT/scripts/seed_kirov_simulation.sql"

echo ""
echo "==> Контейнеры:"
docker compose -f "$COMPOSE_FILE" ps

PUBLIC_API="${PUBLIC_URL%/}/api"
echo ""
echo "==> Проверка API..."
if curl -fsS "${PUBLIC_API}/events?limit=1" >/dev/null 2>&1; then
  echo "OK: ${PUBLIC_API}/events"
elif curl -fsS "http://127.0.0.1/api/events?limit=1" >/dev/null 2>&1; then
  echo "OK локально: http://127.0.0.1/api/events"
  echo "Снаружи пока недоступно — проверь проброс порта на роутере:"
  echo "  внешний :8081 → $(hostname -I 2>/dev/null | awk '{print $1}'):80"
else
  echo "API пока не отвечает — подожди минуту и проверь: curl ${PUBLIC_API}/events?limit=1"
fi

echo ""
echo "============================================"
echo "Готово."
echo "Адрес для APK: ${PUBLIC_API}"
echo "Собрать APK (на Mac):"
echo "  API_BASE_URL=${PUBLIC_API} ./scripts/build-home-server-apk.sh andexevents-public"
echo "============================================"
