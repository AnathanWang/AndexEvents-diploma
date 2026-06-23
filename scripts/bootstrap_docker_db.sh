#!/usr/bin/env bash
# Creates all DB schemas/tables (Flyway + Match init) and loads demo seed data.
# Usage: ./scripts/bootstrap_docker_db.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/deployments/docker/docker-compose.yml"
COMPOSE_PROJECT="andexevents"
COMPOSE=(docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT")

echo "==> Starting Postgres (host port 5433)..."
"${COMPOSE[@]}" up -d postgres

echo "==> Waiting for Postgres..."
for i in $(seq 1 60); do
  if docker exec andexevents-postgres pg_isready -U andexevents -d andexevents -q 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "==> Starting Java services (Flyway applies migrations V1–V9)..."
"${COMPOSE[@]}" up -d --force-recreate users-service events-service auth-service

echo "==> Waiting for Flyway (~25s)..."
sleep 25

echo "==> Ensuring public.\"Match\" table..."
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/deployments/docker/postgres-init/01-match-table.sql" >/dev/null

echo "==> Seeding demo users for matches..."
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_fake_match_profiles.sql" >/dev/null

echo "==> Seeding demo events..."
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_demo_events.sql" >/dev/null

echo "==> Seeding demo event participants..."
docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
  < "$ROOT/scripts/seed_demo_participants.sql" >/dev/null

echo ""
echo "==> Done. Summary:"
docker exec andexevents-postgres psql -U andexevents -d andexevents -c "
SELECT schemaname, count(*) AS tables
FROM pg_tables
WHERE schemaname IN ('users','events','public')
  AND tablename NOT LIKE 'flyway%'
  AND tablename <> 'spatial_ref_sys'
GROUP BY schemaname
ORDER BY schemaname;
"
docker exec andexevents-postgres psql -U andexevents -d andexevents -c "
SELECT 'users' AS schema, count(*) AS rows FROM users.\"User\"
UNION ALL SELECT 'events', count(*) FROM events.\"Event\"
UNION ALL SELECT 'public.Match', count(*) FROM public.\"Match\";
"
echo ""
echo "pgAdmin / DBeaver:"
echo "  Host:     localhost"
echo "  Port:     5433"
echo "  Database: andexevents"
echo "  User:     andexevents"
echo "  Password: andexevents_dev_password"
echo ""
echo "Refresh schemas in pgAdmin (users, events, public)."
