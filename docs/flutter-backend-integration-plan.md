# План: подключение всех сервисов к Flutter-приложению и локальный запуск (Hybrid Go+Java + Firebase)

## 0) Контекст (что есть в репозитории)

В репозитории одновременно живут несколько «поколений» бэкенда. Цель этого плана — собрать **гибрид**:

- часть сервисов берём из **Java (Spring Boot)**
- оставшиеся — из **Go микросервисов**
- всё это прячем за **единым API gateway**, чтобы Flutter использовал один `API_BASE_URL`
- авторизация: **полностью Firebase** (Firebase ID Token в `Authorization: Bearer ...`)

1. **Go микросервисы + Traefik gateway**

- compose: `deployments/docker/docker-compose.yml`
- gateway: Traefik на `:80`, маршрутизация по `PathPrefix(/api/...)`
- сервисы: `auth-service (8001)`, `events-service (8002)`, `users-service (8003)`, `match-service (8005)`, `upload-service (8006)`

2. **Java Spring Boot сервисы** (каждый на своём порту)

- compose: `docker-compose.yml`
- сервисы: `users-service-java (8081)`, `events-service-java (8082)`, `auth-service-java (8083)`
- *нет* API-gateway, поэтому Flutter (который ожидает один `baseUrl`) нужно либо менять, либо добавлять reverse-proxy.

3. **Legacy Node/Express backend** (порт `3000`, историческое)

- код: `backend/`
- важно: в текущем состоянии `backend/src/index.ts` импортирует `./services/minio.service.js`, но файла в `backend/src/services/` нет, т.е. запуск может быть сломан. Не планируйте на него «основной» сценарий без фикса.

Дальше ниже **legacy Node** не рассматривается как целевой вариант, потому что вы хотите полностью перейти на **Firebase**.

## 1) Целевая архитектура: Hybrid Go+Java за одним gateway

Flutter сейчас устроен так, что все запросы идут в **один** `AppConfig.baseUrl` (например `http://localhost:3000/api`) и дальше добавляются пути `/users`, `/events`, `/matches`, `/upload`, `/friends`.

Чтобы подключить гибридный стек без переписывания всех клиентов, нужен **единый API gateway**.

### Решение
Используем **Traefik** как gateway и маршрутизируем часть роутов на **Java**, часть — на **Go**.

Ключевая идея: Flutter знает только `API_BASE_URL=http://.../api`, а внутри gateway распределяет:

- `/api/users` → Java users-service
- `/api/events` → Java events-service
- `/api/auth` → Java auth-service
- `/api/matches` → Go match-service
- `/api/upload` и `/uploads` → Go upload-service

Для этого добавлен отдельный compose-файл под гибридный запуск:
- `deployments/docker/docker-compose.hybrid.yml`

## 2) Авторизация: полностью Firebase (что меняется)

### 2.1. Что должно быть в запросах
Во все API-запросы Flutter → backend отправляем:
- `Authorization: Bearer <Firebase ID Token>`

То есть Flutter должен получать токен через `firebase_auth`:
- `FirebaseAuth.instance.currentUser?.getIdToken()`

### 2.2. Что с БД полем `supabaseUid`
В текущих схемах БД поле называется `"User"."supabaseUid"` (исторически).

Но уже есть Java-миграции, которые добавляют `"firebaseUid"` и бэкфилят одно из другого:
- `services-java/auth-service/src/main/resources/db/migration/V2__firebase_uid.sql`

Рекомендация для перехода:
- считать **истиной** `firebaseUid`
- `supabaseUid` оставить как legacy-алиас (пока не будете делать миграцию с переименованием)

Важно: часть Go сервисов сейчас напрямую ищет пользователя по `"User"."supabaseUid"` и трактует это как Firebase UID (см. комментарии в middleware). Это нужно унифицировать в рамках миграции (см. раздел 6).

## 3) Какие сервисы откуда (явная матрица)

Ниже — **точно какие маршруты** обслуживаются какими сервисами в гибридной схеме.

### 3.1. Маршруты → сервисы

| Путь | Реализация | Откуда берём | Порт в контейнере |
| --- | --- | --- | --- |
| `/api/users/**` | users-service | Java `services-java/users-service` | 8081 |
| `/api/events/**` | events-service | Java `services-java/events-service` | 8082 |
| `/api/auth/**` | auth-service | Java `services-java/auth-service` | 8083 |
| `/api/matches/**` | match-service | Go `services/match-service` | 8005 |
| `/api/upload` | upload-service | Go `services/upload-service` | 8006 |
| `/uploads/**` | upload-service (public files) | Go `services/upload-service` | 8006 |

### 3.2. Что с Friends
В Flutter есть вызовы `/api/friends/**`, но в гибридном Firebase-only стеке сейчас **нет готового friends-service**.

Варианты:
- (рекомендуется) реализовать `friends-service` (Go или Java) и добавить роут в Traefik
- временно отключить/спрятать функционал Friends в UI, пока сервис не готов

Legacy Node friends использовать для Firebase-only не советую.

## 4) Локальный запуск гибридного стека (Hybrid Compose)

### 4.1. Предусловия
- Docker Desktop запущен
- Порты свободны: `80`, `8080`, `5432`, `9000`, `9001`, `6379` (доп. порты сервисов можно не публиковать наружу)

### 4.2. Firebase service account (обязательно)

В текущем hybrid compose-файле хостовый файл:
- `secrets/firebase-service-account.json`

монтируется в Go-контейнеры как:
- `/app/firebase-credentials.json`

Поэтому достаточно убедиться, что `secrets/firebase-service-account.json` существует и содержит Firebase Admin Service Account.

Плюс:
- в `.env`/окружение выставить `FIREBASE_PROJECT_ID`
- для Java сервисов при необходимости выставить `FIREBASE_JWKS_URL` (если они валидируют токен по JWKS)

### 4.3. Поднять всё через Docker Compose

Команда (гибридный compose):
- `docker compose -f deployments/docker/docker-compose.hybrid.yml up -d --build`

Остановить:
- `docker compose -f deployments/docker/docker-compose.hybrid.yml down`

Логи:
- `docker compose -f deployments/docker/docker-compose.hybrid.yml logs -f --tail=200`

### 4.4. Быстрые health-checks

Проверить Traefik:
- `http://localhost:8080` (dashboard)

Проверить публичные эндпоинты через gateway:
- `http://localhost/api/users/health` (если есть)
- `http://localhost/api/events/health` (если есть)
- `http://localhost/api/auth/health` (если есть)
- `http://localhost/api/matches/health` (если есть)
- `http://localhost/api/upload/health` (если есть)

Проверить сервисы напрямую (если опубликованы порты):
- Java: `http://localhost:8081/health`, `http://localhost:8082/health`, `http://localhost:8083/health`
- Go: `http://localhost:8005/health`, `http://localhost:8006/health`

## 5) Настройка Flutter под gateway

### 5.1. Базовый URL (важно: **с `/api`**)

Для Hybrid gateway (Traefik):
- iOS simulator / macOS: `API_BASE_URL=http://localhost/api`
- Android emulator: `API_BASE_URL=http://10.0.2.2/api`
- Физическое устройство: `API_BASE_URL=http://<LAN-IP-вашего-Мака>/api`

Запуск примеры:
- `flutter run --dart-define=API_BASE_URL=http://localhost/api`
- `flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api`

### 5.2. Важная несовместимость в текущем коде Flutter (upload)

`LocalStorageService` сейчас использует **жёстко заданный** `_backendUrl = 'http://localhost:3000'` и ходит на `$_backendUrl/api/upload?...`.

Для микросервисного стека это нужно привести к единому `API_BASE_URL` (иначе upload продолжит ломиться в legacy `:3000`).

Рекомендуемое правило:
- все HTTP-вызовы в приложении должны использовать `AppConfig.baseUrl`
- если нужно «хост без `/api`», вычислять его из `baseUrl` (например, убрать суффикс `/api`)

## 6) План перехода Flutter → Firebase (кратко)

Цель: убрать Supabase Auth из критического пути запросов.

### 6.1. Flutter
1. Добавить Firebase в Flutter (`firebase_core`, `firebase_auth`) и настроить платформы.

   - Android: файл уже есть `Andexevents Google Services.json` (проверьте, что он лежит там, где ожидает Gradle)
   - iOS: есть `Andexevents Google Service Info.plist`

2. Логин (email/google) делаем через Firebase.

3. Во всех запросах вместо Supabase access token используем:

   - `await FirebaseAuth.instance.currentUser?.getIdToken()`

4. На бэкенде создаём/находим пользователя по Firebase UID.

### 6.2. Backend (общие правила)
1. Единый способ маппинга: `firebaseUid → "User".firebaseUid → "User".id`

2. На период миграции допускается alias:

   - если `firebaseUid` пустой, использовать `supabaseUid` (но это временно)

## 7) Wipe пользователей и мероприятий (БД + MinIO)

### 7.1. База данных
В репозитории есть скрипт: `scripts/wipe_db.sql`.

Он должен быть безопасным к отсутствующим таблицам (в гибриде не все таблицы могут существовать).

Запуск пример:
- `psql "postgresql://andexevents:andexevents_dev_password@localhost:5432/andexevents" -f scripts/wipe_db.sql`

### 7.2. MinIO
Есть скрипт: `scripts/wipe_minio.sh`.

Запуск:
- `COMPOSE_FILE=deployments/docker/docker-compose.hybrid.yml ./scripts/wipe_minio.sh`

Примечание: скрипт зависит от имени docker-network. Если сеть называется иначе — выставьте `NETWORK_NAME=...`.

## 8) Маппинг эндпоинтов (что уже совпадает)

### Users
Flutter уже дергает:
- `GET  {baseUrl}/users/me`
- `POST {baseUrl}/users`
- `PUT  {baseUrl}/users/me`
- `PUT  {baseUrl}/users/me/location`
- `GET  {baseUrl}/users/matches?limit=...&latitude=...&longitude=...&radiusKm=...`

Go users-service и Java users-service используют такие же `/api/users/...` пути.

### Events
Flutter дергает:
- `GET  {baseUrl}/events`
- `GET  {baseUrl}/events/{id}`
- `GET  {baseUrl}/events/user/{userId}`
- `POST {baseUrl}/events` (auth)
- `POST {baseUrl}/events/{id}/participate` (auth)
- `DELETE {baseUrl}/events/{id}/participate` (auth)
- `GET {baseUrl}/events/{id}/participants`

Это согласуется с Node/Java; в Go events-service тоже используется `/api/events` (см. compose + сервис).

### Matches
Flutter дергает:
- `GET  {baseUrl}/matches`
- `GET  {baseUrl}/matches/actions?...`
- `POST {baseUrl}/matches/like|dislike|super-like`

В Go это реализовано в `services/match-service` под `/api/matches`.

### Uploads
Flutter (через `LocalStorageService`) ожидает:
- `POST /api/upload?bucket=avatars|events`
- и публичные файлы через `/uploads/...`

Go `upload-service` сделан как drop-in replacement:
- `POST /api/upload` и `GET /uploads/:bucket/:userId/:filename`

Но: сейчас Flutter шлёт **Supabase token**, а upload-service требует **Firebase token**.

### Friends
См. раздел 3.2 — в Firebase-only hybrid сейчас нужно реализовать отдельный friends-service.

## 9) План работ (по шагам)

### Шаг 1. Зафиксировать целевую архитектуру
- Hybrid: Traefik gateway + Java (users/events/auth) + Go (match/upload)

### Шаг 2. Авторизация
- Вы выбрали Firebase-only → делаем миграцию Flutter на Firebase (раздел 6)

### Шаг 3. Устранить «жёсткие URL» в Flutter
- привести `LocalStorageService` и любые прямые `localhost:3000` к `API_BASE_URL`

### Шаг 4. Довести функциональные пробелы по сервисам
- реализовать `friends-service` (Go или Java) и добавить route в Traefik
- убедиться, что users/events/match/upload покрывают все используемые Flutter-экраном сценарии

### Шаг 5. Smoke-test (минимальный)
1. поднять docker (`make docker-up`)
2. запустить Flutter с `--dart-define=API_BASE_URL=.../api`
3. пройти логин
4. проверить:
   - загрузка профиля (`/users/me`)
   - обновление локации (`/users/me/location`)
   - список событий (`/events`)
   - матчи (`/matches`)
   - загрузка фото (upload)

## 10) Troubleshooting

- **Порт 80 занят**: поменяйте проброс Traefik в `deployments/docker/docker-compose.hybrid.yml`, например `8088:80`, и тогда `API_BASE_URL=http://localhost:8088/api`.
- **401 на всех запросах**: проверьте, что Flutter отправляет Firebase ID token, а сервисы настроены на Firebase.
- **Физическое устройство не видит localhost**: используйте `http://LAN-IP/api`.
- **CORS**: для Flutter mobile обычно не критично (в отличие от web), но для Flutter web нужно добавить origin в gateway/сервисы.

```text

end


