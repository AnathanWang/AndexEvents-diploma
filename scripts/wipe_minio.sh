#!/usr/bin/env bash
set -euo pipefail

# DANGER: This removes ALL objects from MinIO buckets used by the app.
# It uses the minio/mc client container to connect to the docker-compose MinIO.

COMPOSE_FILE="${COMPOSE_FILE:-deployments/docker/docker-compose.yml}"
ALIAS_NAME="local"

# Use docker compose to run an ephemeral mc client on the same network.
# We assume the compose project network name is `andexevents-andexevents-network` when run from repo root.
# If your network differs, set NETWORK_NAME env var.
NETWORK_NAME="${NETWORK_NAME:-andexevents-andexevents-network}"

echo "[wipe_minio] Using compose file: ${COMPOSE_FILE}"
echo "[wipe_minio] Using network: ${NETWORK_NAME}"

docker run --rm \
  --network "${NETWORK_NAME}" \
  minio/mc:latest \
  /bin/sh -c "
    mc alias set ${ALIAS_NAME} http://andexevents-minio:9000 andexevents andexevents_minio_secret;
    mc rm -r --force ${ALIAS_NAME}/avatars;
    mc rm -r --force ${ALIAS_NAME}/events;
    mc rm -r --force ${ALIAS_NAME}/media;
    echo 'MinIO buckets wiped.';
  "
