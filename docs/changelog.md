# Andex Events — Changelog (Audit & Refactoring)

## Date: 2026-02-17

### Summary
Comprehensive audit and refactoring of the entire project based on code review findings.

---

### Infrastructure Changes

#### Go Services → Legacy
- **Moved** `services/auth-service`, `services/users-service`, `services/events-service` (Go) → `legacy/go-services/`
- Java implementations in `services-java/` are now canonical for auth, users, and events
- Active Go services remaining: `services/match-service`, `services/upload-service`

#### Docker Compose
- **Recreated** `deployments/docker/docker-compose.yml` — Unified single compose file
  - Java services: auth (8083), users (8081), events (8082)
  - Go services: match (8005), upload (8006)
  - Infrastructure: Traefik, PostgreSQL 16+PostGIS, Redis 7, MinIO
- **Deleted** `deployments/docker/docker-compose.hybrid.yml` (obsolete)
- **Updated** root `docker-compose.yml` — Renamed services, fixed build contexts

#### Makefile
- **Recreated** — Removed all references to Go auth/users/events services
- Build targets: `build-java`, `build-go` (match/upload only), `test-java`, `test-go`

---

### Java Backend Fixes

#### Auth Service
- **Created** `V1__init.sql` Flyway migration (was missing — V2 existed without V1)
- **Fixed** `UserLookupRepository.java` — Cross-schema query now uses `users."User"` instead of unqualified `"User"`
- **Fixed** `V2__firebase_uid.sql` — All table references now use `users."User"` schema prefix

---

### Flutter Fixes

#### Security
- **Removed** token/PII leak in `user_service.dart` — Eliminated `print('DEBUG: Token начинается с: ${token.substring(0, 20)}...')` and similar lines

#### Apple Sign-In Removal
- **Removed** Apple sign-in button from `login_screen.dart`
- **Removed** Apple sign-in button from `register_screen.dart`
- Reason: No Apple Developer account

#### Logging (105+ instances)
- **Replaced ALL** `print()` / `debugPrint()` → `LoggerService.debug/info/warning/error` across ~13 presentation files and all service files
- Files updated: `user_service.dart`, `upload_service.dart`, `geocoding_service.dart`, `login_screen.dart`, `register_screen.dart`, `profile_screen.dart`, `matches_screen.dart`, `events_feed_screen.dart`, `event_detail_screen.dart`, `map_screen.dart`, `create_event_screen.dart`, `edit_event_screen.dart`, and more

#### Deprecated API Fixes (90 instances)
- **Replaced ALL** `.withOpacity(x)` → `.withValues(alpha: x)` across 20 files via automated sed replacement
- Fixed 1 multiline case manually in `events_feed_screen.dart`

#### ReportService (Complete Rewrite)
- Was: Fake stub with `Future.delayed` and hardcoded data
- Now: Real API client (`POST /api/users/reports`, `GET /api/users/reports`, `PUT /api/users/reports/{id}`) with `IdTokenProvider` for auth and proper error handling

#### EventService
- Added `LoggerService` import
- Added `.timeout(AppConfig.receiveTimeout)` to `createEvent` and `getEvents`
- Fixed `getEventParticipants` — now includes Authorization header and timeout

#### LocalStorageService
- **Fixed** `_parseJson()` method — Replaced regex-based JSON parser (`RegExp(r'"fileUrl"\s*:\s*"([^"]+)"')`) with proper `jsonDecode()`

#### AuthBloc (Infinite Loop Fix)
- Added `_handlingAuthAction` guard flag
- `authStateChanges` listener now skips `AuthCheckRequested` when a login/register/logout handler is already running
- Prevents double-emit of `AuthAuthenticated` on every login

#### MaterialApp Rebuild Fix
- **Before:** `BlocBuilder<AuthBloc, AuthState>` wrapped the entire `MaterialApp` with a `ValueKey` that forced widget tree destruction on every state change
- **After:** `MaterialApp` is built once in `_buildMaterialApp()`. Only the `home` widget uses `BlocBuilder` to switch between screens

#### Navigator Context Crash Fix
- `edit_profile_screen.dart` — Fixed `navigatorContext` used after `Navigator.pop()` (crashed with "deactivated widget's ancestor" error)
- Now uses `Navigator.pop(true)` and parent screens handle the success notification via `push<bool>` result

#### Edit Profile Structure Fix
- Fixed broken method boundaries in `edit_profile_screen.dart` — `_pickImage`, `_pickAdditionalPhotos`, `_removeExistingPhoto` methods had merged/missing closing braces

#### Dead Code Removal
- **Deleted** `lib/core/error/exceptions.dart` — Zero imports (only used by dead api_client.dart)
- **Deleted** `lib/core/error/failures.dart` — Zero imports anywhere
- **Deleted** `lib/core/network/api_client.dart` — Unused Dio-based HTTP client wrapper (services use their own HTTP clients)
- **Removed** empty `lib/core/error/` and `lib/core/network/` directories

#### API Key Validation
- `GeocodingService` — Added `_hasApiKey` check before making Yandex API calls
- Returns `null` / empty list with warning log instead of sending empty `apikey=` parameter

#### SampleData Fallback Removal
- `user_service.dart` — Removed `SampleData` import and fake data fallback on 404; now returns empty list

---

### Tests Added

- `test/data/models/user_model_test.dart` — 7 tests (fromJson, toJson, roundtrip, copyWith, null handling)
- `test/data/models/event_model_test.dart` — 12 tests (fromJson, participants, creator extraction, fallbacks, copyWith)
- `test/data/models/report_model_test.dart` — Extended with 3 new tests (default status, event report, custom status)
- `test/core/services/logger_service_test.dart` — 7 tests (all methods, error/stacktrace handling)
- `test/core/config/app_config_test.dart` — 6 tests (constants validation, timeouts, baseUrl)
- `test/presentation/auth/auth_bloc_test.dart` — 10 tests (event/state equality, Equatable behavior)
- **Total: 56 tests passing**

---

### Documentation Added

- `docs/architecture.md` — System architecture, tech stack, service breakdown
- `docs/setup.md` — Local development setup guide
- `docs/api-reference.md` — Complete REST API documentation
- `docs/services.md` — Detailed service documentation
- `docs/changelog.md` — This file

---

### Known Remaining Issues (Non-Blocking)

1. **Inconsistent singleton patterns** — `LocalStorageService` and `ReportService` use singletons; other services don't. Consider using a DI container (e.g., `get_it`)
2. **Production URL placeholder** — `https://api.andexevents.com/api` in `AppConfig.baseUrl` needs real domain
3. **Duplicate Yandex API key configs** — `MapConfig.yandexMapKitApiKey` vs `AppConfig.yandexMapsApiKey` from different env vars
4. **Java SonarQube warnings** — Raw types in test code, duplicated string literals in controllers
5. **`ProgressUploadService`** in `upload_service.dart` may be a duplicate of `LocalStorageService` — consolidation candidate
