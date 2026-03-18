# Plan: split Auth vs Users, unify on Firebase (2026-01-29)

## Goals

- **Before changes:** push current state to GitHub (no secrets).
- **No Friends service:** drop the friends feature for now.
- **Clear responsibility split:**
  - **auth-service** = authentication utilities only (token verification / health)
  - **users-service** = user profiles and related profile endpoints
- **Unify auth across Go services on Firebase** (remove Supabase JWT usage from users-service and match-service).
- **Enable events-service in docker-compose + Traefik**.

## Preconditions / safety

- Verify `secrets/` and credentials files are **gitignored** and not staged.
- Confirm Git remote is configured (`origin`) and push works.

## Step 0 — Push current state (baseline)

1. `git status` must be clean or explicitly reviewed.
2. If there are local changes, commit with a clear message.
3. `git push` to GitHub.

## Step 1 — Decide user identity mapping in DB

- Current DB mapping used by upload-service: `firebaseUid -> "User"."supabaseUid" -> "User"."id"`.
- Confirm in Prisma schema whether there is a dedicated `firebaseUid` column.
  - If **no**, keep using `supabaseUid` as the auth UID (temporary) and document it.
  - If **yes**, migrate code to `firebaseUid` everywhere.

## Step 2 — Make auth-service “auth-only”

- Keep:
  - `GET /health`, `GET /ready`
  - `POST /api/auth/verify` (Firebase token verification)
- Remove from auth-service:
  - `/api/users/*` profile endpoints

## Step 3 — Make users-service own `/api/users/*` (Firebase)

- Switch middleware from Supabase JWT to **Firebase ID token** verification.
- Add DB lookup: Firebase UID → DB user ID.
- Ensure routes match the client contract:
  - `POST /api/users`
  - `GET /api/users/me`
  - `PUT /api/users/me`
  - `PUT /api/users/me/location`
  - `POST /api/users/me/onboarding`
  - `GET /api/users/matches`
  - `GET /api/users/:id` (public)

## Step 4 — Switch match-service to Firebase

- Replace Supabase JWT middleware with Firebase verification.
- Keep the same API paths and responses.

## Step 5 — Enable events-service

- Add `events-service` to docker-compose and Traefik:
  - Port: `8002`
  - Router rule: `PathPrefix(/api/events)`
- Confirm it starts and responds to `/health`.

## Step 6 — Routing updates (Traefik)

- Route `PathPrefix(/api/auth)` → auth-service.
- Route `PathPrefix(/api/users)` → users-service.
- Keep existing:
  - `PathPrefix(/api/matches)` → match-service
  - `PathPrefix(/api/upload)` and `PathPrefix(/uploads)` → upload-service
  - `PathPrefix(/api/events)` → events-service

## Step 7 — Docs updates

- Update microservice docs to reflect:
  - Firebase auth everywhere
  - Current ports
  - Ownership split (auth-service vs users-service)
- Update `services/docs/api-reference.md` and `services/docs/architecture.md` to match reality.

## Step 8 — Verification

- `go test ./...` for:
  - `services/auth-service`
  - `services/users-service`
  - `services/match-service`
  - `services/events-service`
  - `services/upload-service`
- `docker compose up -d --build` and smoke-check:
  - `POST /api/auth/verify`
  - `GET /health` for each service

## Step 9 — Push changes

- Commit with message like: `refactor: split auth/users and unify firebase`
- Push to GitHub.
