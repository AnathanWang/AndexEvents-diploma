# Upload Service

Drop-in replacement for the legacy Node upload endpoint and public `/uploads/*` files, but stores objects in MinIO.

## Legacy compatibility

This service preserves the existing client contract from the legacy Node backend:

- Upload endpoint: `POST /api/upload?bucket=avatars|events`
- Multipart field name: `file`
- Public URL shape: `/uploads/{bucket}/{userId}/{filename}`
- When `bucket=avatars`, updates `"User"."photoUrl"` in DB

## Base URL

- Service: `http://localhost:8006`
- Via Traefik (recommended): `http://localhost` (routes `/api/upload` and `/uploads`)

## Auth

Protected endpoint requires a Firebase ID token:

`Authorization: Bearer <firebase-id-token>`

> Internally the service maps `firebaseUid -> "User".supabaseUid -> "User".id`.

## Endpoints

### POST `/api/upload?bucket=avatars|events`

Uploads an image file (multipart/form-data field name: `file`).

Query params:

- `bucket` (optional): `avatars` | `events` (default: `events`)

Validation:

- Allowed extensions: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
- Size limits:
  - `avatars`: 5MB
  - `events`: 10MB

- `bucket=avatars`:
  - Max size: 5MB
  - Also updates `"User"."photoUrl"` in DB to the returned `fileUrl`
- `bucket=events`:
  - Max size: 10MB

Response (legacy-compatible):

```json
{
  "success": true,
  "fileUrl": "http://localhost/uploads/avatars/<userId>/<filename>",
  "file": {
    "name": "1700000000000-ab12cd34.jpg",
    "size": 12345,
    "bucket": "avatars"
  }
}
```

Errors:

```json
{ "success": false, "message": "Unauthorized" }
```

```json
{ "success": false, "message": "No file uploaded" }
```

```json
{ "success": false, "message": "Invalid bucket name" }
```

```json
{ "success": false, "message": "Invalid file extension. Only jpg, png, gif, webp are allowed" }
```

```json
{ "success": false, "message": "File too large (max 5MB)" }
```

```json
{ "success": false, "message": "Upload failed" }
```

### GET `/uploads/:bucket/:userId/:filename`

Publicly streams the object from MinIO (used by the existing clients).

- Buckets supported: `avatars`, `events`
- Basic path validation blocks traversal attempts

Responses:

- `200` streams the object
- `404` if object does not exist
- `400` for an invalid path

## Configuration

Environment variables:

- `PORT` (default `8006`)
- `ENVIRONMENT` (`development`|`production`)
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL_MODE`
- `MINIO_ENDPOINT` (e.g. `minio:9000` in docker-compose, `localhost:9000` on host)
- `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_USE_SSL`
- `FIREBASE_CREDENTIALS_FILE`, `FIREBASE_PROJECT_ID`
- `UPLOADS_PUBLIC_BASE_URL` (optional): forces returned `fileUrl` base (useful behind gateways)

## Local migration (legacy uploads -> MinIO)

Copies `backend/public/uploads/{bucket}/{userId}/{filename}` into MinIO as `{bucket}/{userId}/{filename}`.

Notes:

- Only `avatars` and `events` are migrated; other folders are skipped.
- Object key in MinIO is `{userId}/{filename}` (bucket is the top-level folder).

- Dry run:
  - `cd services/upload-service && MINIO_ENDPOINT=localhost:9000 MINIO_ACCESS_KEY=andexevents MINIO_SECRET_KEY=andexevents_minio_secret MINIO_USE_SSL=0 go run ./cmd/migrate --src ../../backend/public/uploads --dry-run`
- Run:
  - `./scripts/migrate_local_uploads_to_minio.sh`

## Wipe (danger)

- DB wipe: `scripts/wipe_db.sql`
- MinIO wipe: `./scripts/wipe_minio.sh`

Do not run these on production without a backup.
