# Andex Events — Local Development Setup

## Prerequisites

- **Flutter SDK** ^3.9.2 ([Install guide](https://docs.flutter.dev/get-started/install))
- **Java 21** (JDK, for building Java services)
- **Go 1.23+** (for match-service and upload-service)
- **Docker & Docker Compose** (for infrastructure)
- **Maven** (for Java services, or use `./mvnw` wrapper)
- **Firebase project** with Authentication enabled

## Quick Start

### 1. Start Infrastructure

```bash
# From project root
cd deployments/docker
docker compose up -d postgres redis minio
```

This starts:
- PostgreSQL 16 on `localhost:5432`
- Redis 7 on `localhost:6379`
- MinIO on `localhost:9000` (console: `localhost:9001`)

### 2. Build & Run Java Services

```bash
# From project root
cd services-java
./mvnw clean package -DskipTests

# Run each service (in separate terminals):
java -jar auth-service/target/auth-service-*.jar
java -jar users-service/target/users-service-*.jar
java -jar events-service/target/events-service-*.jar
```

Or use Docker:
```bash
cd deployments/docker
docker compose up -d auth-service users-service events-service
```

### 3. Build & Run Go Services

```bash
# Match service
cd services/match-service
go build -o match-service ./cmd/main.go
./match-service

# Upload service
cd services/upload-service
go build -o upload-service ./cmd/main.go
./upload-service
```

### 4. Run Flutter App

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run \
  --dart-define=YANDEX_MAPKIT_API_KEY=<your-key> \
  --dart-define=YANDEX_API_KEY=<your-key>
```

## Environment Variables

### Java Services

| Variable | Default | Description |
|----------|---------|-------------|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://localhost:5432/andexevents` | Database URL |
| `SPRING_DATASOURCE_USERNAME` | `andexevents` | DB username |
| `SPRING_DATASOURCE_PASSWORD` | `andexevents_dev_password` | DB password |
| `FIREBASE_PROJECT_ID` | — | Firebase project ID for JWT validation |
| `FLYWAY_ENABLED` | `true` (users/events), `false` (auth) | Enable Flyway migrations |
| `SERVER_PORT` | `8081`/`8082`/`8083` | HTTP server port |

### Go Services

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgres://andexevents:...@localhost:5432/andexevents` | PostgreSQL connection |
| `MINIO_ENDPOINT` | `localhost:9000` | MinIO S3 endpoint |
| `MINIO_ACCESS_KEY` | `minioadmin` | MinIO access key |
| `MINIO_SECRET_KEY` | `minioadmin` | MinIO secret key |

### Flutter

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Override base URL (optional) |
| `YANDEX_MAPKIT_API_KEY` | Yandex MapKit API key |
| `YANDEX_API_KEY` | Yandex Geocoding API key |
| `YANDEX_MAPS_API_KEY` | Yandex Maps API key |

Pass via `--dart-define`:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100/api
```

## Service Ports

| Service | Port | Health Check |
|---------|------|-------------|
| auth-service (Java) | 8083 | `GET /actuator/health` |
| users-service (Java) | 8081 | `GET /actuator/health` |
| events-service (Java) | 8082 | `GET /actuator/health` |
| match-service (Go) | 8005 | `GET /health` |
| upload-service (Go) | 8006 | `GET /health` |
| PostgreSQL | 5432 | — |
| Redis | 6379 | — |
| MinIO API | 9000 | — |
| MinIO Console | 9001 | — |
| Traefik | 80 | `GET /ping` |
| Traefik Dashboard | 8080 | — |

## Database

The database name is `andexevents`. Each Java service uses its own schema:
- `users` (users-service)
- `events` (events-service)
- `auth` (auth-service — metadata only)

Flyway manages migrations automatically on startup (when `FLYWAY_ENABLED=true`).

### Manual DB Reset

```bash
psql -U andexevents -d andexevents -f scripts/wipe_db.sql
```

## Running Tests

### Flutter
```bash
flutter test
```

### Java
```bash
cd services-java
./mvnw test
```

### Go
```bash
cd services/match-service && go test ./...
cd services/upload-service && go test ./...
```

## Firebase Setup

1. Place `Andexevents Google Services.json` in `android/app/google-services.json`
2. Place `Andexevents Google Service Info.plist` in `ios/Runner/GoogleService-Info.plist`
3. Place `Andexevents Firebase Admin SDK.json` in `secrets/firebase-service-account.json`
4. Set `FIREBASE_PROJECT_ID` environment variable for Java services

## Secrets

Sensitive files are stored in `secrets/` (gitignored):
- `firebase-service-account.json` — Firebase Admin SDK credentials
- `supabase_anon_key.txt` — Legacy Supabase key
- `yandex_geocode_api_key.txt` — Yandex Geocoding API key
- `yandex_mapkit_api_key.txt` — Yandex MapKit API key
