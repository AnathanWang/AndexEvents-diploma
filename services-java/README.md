# Java microservices (Spring Boot)

This folder contains Java rewrites of core services (Strangler-friendly):

- `users-service` (port 8081)
- `events-service` (port 8082)
- `auth-service` (port 8083)

## Run with Docker Compose

Set Firebase env vars (used by these Java services) and start:

```bash
FIREBASE_PROJECT_ID=... FIREBASE_JWKS_URL=... docker compose up --build
```

Local build (per-service):

```bash
mvn -q -DskipTests package
```

If Maven is not installed locally, install it with:

```bash
brew install maven
```

Health endpoints:

- `http://localhost:8081/health`
- `http://localhost:8082/health`
- `http://localhost:8083/health`

Swagger UI:

- `http://localhost:8081/swagger-ui`
- `http://localhost:8082/swagger-ui`
- `http://localhost:8083/swagger-ui`

## API compatibility

These services are implemented to match the current Node backend endpoints:

- Users: `/api/users/*`
- Events: `/api/events/*`

Auth is implemented as a small helper service:

- `GET /api/auth/me`
- `POST /api/auth/validate`

Note: events `GET` routes support optional auth; invalid Bearer tokens are ignored (Node behavior).
