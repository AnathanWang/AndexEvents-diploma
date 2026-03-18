#!/usr/bin/env bash
set -euo pipefail

# Copies legacy local uploads (backend/public/uploads/**) into MinIO buckets.
# Uses the Go migration command inside upload-service.

SRC_DIR="${SRC_DIR:-backend/public/uploads}"

echo "[migrate] SRC_DIR=${SRC_DIR}"

pushd services/upload-service >/dev/null

# MINIO_ENDPOINT/MINIO_ACCESS_KEY/MINIO_SECRET_KEY/MINIO_USE_SSL must be set if not default.
# Example for docker-compose MinIO from host:
#   MINIO_ENDPOINT=localhost:9000 MINIO_ACCESS_KEY=andexevents MINIO_SECRET_KEY=andexevents_minio_secret MINIO_USE_SSL=0 \
#   go run ./cmd/migrate --src ../../backend/public/uploads

go run ./cmd/migrate --src "../../${SRC_DIR}"

popd >/dev/null
