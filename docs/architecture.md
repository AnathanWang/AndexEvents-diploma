# Andex Events — Architecture Overview

## System Architecture

Andex Events is a location-based social events platform with a Flutter mobile client, Java/Go hybrid backend, and PostgreSQL + MinIO infrastructure.

```
┌─────────────────┐
│  Flutter Mobile  │  (iOS + Android)
│  Client (Dart)   │
└───────┬─────────┘
        │ HTTP/REST
        ▼
┌─────────────────┐
│   Traefik API   │  Reverse proxy + routing
│    Gateway       │  Port 80
└───────┬─────────┘
        │
        ├──────────────────┬──────────────────┬──────────────────┬──────────────────┐
        ▼                  ▼                  ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ auth-service │  │users-service │  │events-service│  │match-service │  │upload-service│
│ (Java/Spring)│  │(Java/Spring) │  │(Java/Spring) │  │   (Go/Gin)   │  │   (Go/Gin)   │
│  Port 8083   │  │  Port 8081   │  │  Port 8082   │  │  Port 8005   │  │  Port 8006   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │                 │
       └─────────────────┴────────┬────────┴─────────────────┘                 │
                                  ▼                                            ▼
                         ┌──────────────┐                             ┌──────────────┐
                         │ PostgreSQL   │                             │    MinIO      │
                         │ 16 + PostGIS │                             │  S3 Storage   │
                         │  Port 5432   │                             │  Port 9000    │
                         └──────────────┘                             └──────────────┘
```

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile | Flutter (Dart) | SDK ^3.9.2 |
| Java Services | Spring Boot | 3.3.5 |
| Go Services | Go + Gin | 1.23–1.24 |
| Database | PostgreSQL + PostGIS | 16 |
| Object Storage | MinIO | Latest |
| Cache | Redis | 7 |
| API Gateway | Traefik | v3.0 |
| Auth | Firebase Authentication | — |
| Container | Docker Compose | — |

## Service Breakdown

### Java Services (`services-java/`)

| Service | Port | Schema | Responsibility |
|---------|------|--------|---------------|
| `auth-service` | 8083 | `auth` | JWT validation gateway. Verifies Firebase tokens, resolves internal user IDs. Stateless — no owned tables. |
| `users-service` | 8081 | `users` | User CRUD, profile management, location updates, match retrieval, reports. Owns the `"User"` table. |
| `events-service` | 8082 | `events` | Event CRUD, participation, location-based queries (PostGIS). Owns `"Event"` and `"Participant"` tables. |

All Java services use:
- **Spring Boot 3.3.5** with Java 21
- **Flyway** for database migrations (each service has its own schema)
- **Firebase JWT verification** via JWKS
- Shared database `andexevents` with schema-per-service isolation

### Go Services (`services/`)

| Service | Port | Responsibility |
|---------|------|---------------|
| `match-service` | 8005 | Location-based matching (proximity queries, seen-tracking) |
| `upload-service` | 8006 | File/image upload to MinIO S3, migration scripts |

## Database Architecture

Single PostgreSQL 16 + PostGIS instance with schema isolation:

- **`users` schema** — `"User"` table (managed by `users-service`)
- **`events` schema** — `"Event"`, `"Participant"` tables (managed by `events-service`)
- **`auth` schema** — Flyway history only (auth-service reads from `users."User"`)
- **`public` schema** — PostGIS extensions

Each service's Flyway migrations are in:
```
services-java/{service}/src/main/resources/db/migration/
```

## Flutter Client Architecture

The Flutter app follows **BLoC (Business Logic Component)** pattern:

```
lib/
├── app/                    # App entry point (AndexApp widget)
├── config/                 # Map config (API keys)
├── core/
│   ├── auth/               # IdTokenProvider (Firebase token retrieval)
│   ├── config/             # AppConfig (URLs, timeouts, constants)
│   └── services/           # LoggerService
├── data/
│   ├── models/             # UserModel, EventModel, ReportModel, etc.
│   └── services/           # API clients (UserService, EventService, etc.)
└── presentation/
    ├── auth/               # AuthBloc + login/register screens
    ├── events/             # EventBloc + event screens
    ├── home/               # HomeShell + map/feed/matches/profile tabs
    ├── onboarding/         # Onboarding screen
    ├── profile/            # ProfileBloc + edit profile
    └── widgets/            # Reusable components
```

### Key Patterns

- **LoggerService**: Used everywhere instead of `print()`/`debugPrint()`
- **IdTokenProvider**: Centralized Firebase token retrieval with retry logic
- **BLoC + Equatable**: State management with immutable states and events
- **http package**: Direct HTTP calls (no Dio except GeocodingService)

## Infrastructure

### Docker Compose

The canonical Docker Compose file is at `deployments/docker/docker-compose.yml`.

Services included:
- `traefik` — API Gateway (handles routing to all services)
- `postgres` — PostgreSQL 16 with PostGIS
- `redis` — Redis 7 (caching)
- `minio` — MinIO S3 storage
- All 5 application services

### Makefile

Common targets:
- `make build-java` — Build all Java services via Maven
- `make build-go` — Build match-service and upload-service
- `make test-java` — Run Java tests
- `make test-go` — Run Go tests
- `make up` / `make down` — Docker Compose up/down
- `make flutter-test` — Run Flutter tests
