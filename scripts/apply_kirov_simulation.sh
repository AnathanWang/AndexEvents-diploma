#!/usr/bin/env bash
# Generate and apply Kirov simulation seed (users + events across the city).
# Usage: ./scripts/apply_kirov_simulation.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/deployments/docker/docker-compose.yml"
COMPOSE_PROJECT="andexevents"

echo "==> Generating simulation SQL..."
python3 "$ROOT/scripts/generate_kirov_simulation.py"

echo "==> Applying seed_kirov_simulation.sql..."
if docker ps --format '{{.Names}}' | grep -q '^andexevents-postgres$'; then
  docker exec -i andexevents-postgres psql -U andexevents -d andexevents \
    < "$ROOT/scripts/seed_kirov_simulation.sql"
else
  echo "Container andexevents-postgres not running."
  echo "Start stack: ./scripts/docker-up.sh"
  echo "Or run SQL manually:"
  echo "  psql \"postgresql://andexevents:andexevents_dev_password@localhost:5433/andexevents\" -f scripts/seed_kirov_simulation.sql"
  exit 1
fi

echo ""
echo "==> Done."
