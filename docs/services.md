# Andex Events — Services Documentation

## Service Overview

The Andex Events platform comprises 5 microservices:

| Service | Language | Framework | Port | Status |
|---------|----------|-----------|------|--------|
| auth-service | Java 21 | Spring Boot 3.3.5 | 8083 | Active |
| users-service | Java 21 | Spring Boot 3.3.5 | 8081 | Active |
| events-service | Java 21 | Spring Boot 3.3.5 | 8082 | Active |
| match-service | Go 1.23 | Gin | 8005 | Active |
| upload-service | Go 1.24 | Gin | 8006 | Active |

Legacy Go implementations of auth, users, and events services have been moved to `legacy/go-services/`.

---

## Auth Service (Java)

**Path:** `services-java/auth-service/`

### Purpose
Stateless JWT validation gateway. Verifies Firebase ID tokens and resolves Firebase UIDs to internal user IDs. Does not own any database tables.

### Architecture
- **AuthFilter** — HTTP filter that intercepts requests, validates JWT, looks up user ID
- **FirebaseJwtVerifier** — RSA JWT verification using Firebase JWKS endpoint
- **UserLookupRepository** — JdbcTemplate query against `users."User"` table
- **AuthContext** — Request attribute carrying (uid, email, userId)

### Database
- Schema: `auth` (Flyway history only)
- Reads from: `users."User"` table (cross-schema)
- Owned tables: None

### Flyway Migrations
- `V1__init.sql` — Schema setup, grants on users schema
- `V2__firebase_uid.sql` — Adds firebaseUid/supabaseUid columns and indexes

---

## Users Service (Java)

**Path:** `services-java/users-service/`

### Purpose
User profile management including CRUD, onboarding, location updates, proximity matching, and report handling.

### Architecture
- **UserController** — REST endpoints for user operations
- **UserRepository** — JdbcTemplate-based data access with PostGIS queries
- **AuthFilter** — JWT validation (same pattern as auth-service)
- **FirebaseJwtVerifier** — Firebase JWT validation

### Database
- Schema: `users`
- Owned tables: `"User"`

### Flyway Migrations
- `V1__init.sql` — Creates `"User"` table with all profile fields, location, preferences
- `V2__firebase_uid.sql` — Adds Firebase UID column and indexes
- `V3__add_reports.sql` — Adds reports table

### Key Features
- PostGIS-based proximity search for matches
- Profile completeness validation
- Onboarding flow
- User location tracking
- Report submission and retrieval

---

## Events Service (Java)

**Path:** `services-java/events-service/`

### Purpose
Event lifecycle management — creation, discovery, participation, and moderation.

### Architecture
- **EventController** — REST endpoints for event CRUD and participation
- **EventRepository** — JdbcTemplate with PostGIS spatial queries
- **ParticipantRepository** — Manages event participation records
- **AuthFilter** — JWT validation

### Database
- Schema: `events`
- Owned tables: `"Event"`, `"Participant"`

### Flyway Migrations
- `V1__init.sql` — Creates `"Event"` and `"Participant"` tables with PostGIS geometry
- `V2__firebase_uid.sql` — Firebase UID support

### Key Features
- Location-based event discovery (PostGIS `ST_DWithin`)
- Category and status filtering
- Pagination (offset-based)
- Participation management (join/leave)
- Event moderation (PENDING → APPROVED/REJECTED)

---

## Match Service (Go)

**Path:** `services/match-service/`

### Purpose
Advanced location-based matching with tracking of seen users.

### Architecture
- **Handler** — Gin HTTP handlers
- **Repository** — PostgreSQL queries with PostGIS
- **Service** — Business logic layer
- **Middleware** — Auth (Firebase JWT) + CORS

### Endpoints (см. также `services/match-service/cmd/main.go`)
- `GET /api/matches` — взаимные мэтчи и связанные списки
- `GET /api/matches/actions`, `GET /api/matches/incoming-likes`
- `POST /api/matches/like`, `POST /api/matches/dislike`, `POST /api/matches/super-like`

---

## Upload Service (Go)

**Path:** `services/upload-service/`

### Purpose
File/image upload to MinIO S3-compatible storage.

### Architecture
- **Handler** — Multipart form upload handling
- **MinIO client** — S3 operations (put, get, delete)
- **Migration** — Database migration for upload metadata

### Endpoints (см. `services/upload-service/cmd/main.go`)
- `POST /api/upload` — загрузка файла (multipart, Firebase auth)
- `DELETE /api/upload` — удаление фото (Firebase auth)
- `GET /uploads/:bucket/:userId/:filename` — публичная выдача файла

### Storage
- MinIO S3 bucket for file storage
- PostgreSQL for upload metadata

---

## Shared Infrastructure

### PostgreSQL 16 + PostGIS
- Single instance, schema-per-service isolation
- PostGIS extension for spatial queries
- Connection: `jdbc:postgresql://localhost:5432/andexevents`

### Redis 7
- Session caching and rate limiting
- Connection: `redis://localhost:6379`

### MinIO
- S3-compatible object storage for user photos and event images
- API: `http://localhost:9000`
- Console: `http://localhost:9001`

### Traefik v3
- API Gateway and reverse proxy
- Routes requests to appropriate services based on path prefix
- Configuration: `deployments/docker/docker-compose.yml`

### Routing Rules (Traefik)
| Path Prefix | Destination |
|-------------|-------------|
| `/api/auth` | auth-service:8083 |
| `/api/users` | users-service:8081 |
| `/api/events` | events-service:8082 |
| `/api/matches` | match-service:8005 |
| `/api/upload`, `/uploads` | upload-service:8006 |
