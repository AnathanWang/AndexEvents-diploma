# 6. Backend на Go (Gin)

Два активных сервиса: **`match-service`** и **`upload-service`**. HTTP-фреймворк — **Gin**. Драйвер БД — **pgx** (`pgxpool`). Общий код Firebase — пакет **`shared/pkg/firebase`**.

## 6.1 Общие требования к окружению (Docker Compose)

Оба сервиса в compose:

- подключаются к Postgres по `DB_HOST=postgres`;
- монтируют **Firebase Admin SDK** JSON с хоста `secrets/firebase-service-account.json` в **`/app/firebase-credentials.json`**;
- задают `FIREBASE_CREDENTIALS_FILE=/app/firebase-credentials.json` и `FIREBASE_PROJECT_ID`.

Локальный запуск без Docker — см. переменные в `internal/config/config.go` каждого сервиса и [`../setup.md`](../setup.md).

---

## 6.2 match-service

**Каталог:** `services/match-service/`  
**Точка входа:** `cmd/main.go`  
**Порт по умолчанию:** `8005` (переменная окружения `PORT`)

### Конфигурация (`internal/config/config.go`)

| Переменная | По умолчанию (код) | Описание |
|------------|-------------------|----------|
| `PORT` | 8005 | HTTP-порт |
| `ENVIRONMENT` | development | режим Gin |
| `DB_HOST` | localhost | хост Postgres |
| `DB_PORT` | 5432 | порт |
| `DB_USER` | andexadmin | пользователь БД |
| `DB_PASSWORD` | andexevents | пароль |
| `DB_NAME` | andexevents | имя БД |
| `FIREBASE_PROJECT_ID` | "" | проект Firebase |
| `FIREBASE_CREDENTIALS_FILE` | "" | путь к JSON сервисного аккаунта (**обязателен** для старта в `main`) |

В compose используются значения, согласованные с Java-сервисами (`andexevents` / `andexevents_dev_password`).

### Маршруты

Группа **`/api/matches`** с middleware **`AuthMiddleware(firebaseClient, pool)`** — все методы ниже требуют заголовок:

`Authorization: Bearer <firebase-id-token>`

| Метод | Путь | Назначение |
|-------|------|------------|
| GET | `/api/matches` | Взаимные мэтчи; опционально `?eventId=` |
| GET | `/api/matches/actions` | Пользователи по действию текущего пользователя; обязателен query `action` ∈ `LIKE`, `DISLIKE`, `SUPER_LIKE`; опционально `eventId`, `limit` (1…200, по умолчанию 50) |
| GET | `/api/matches/incoming-likes` | Входящие лайки; опционально `eventId`, `limit` |
| POST | `/api/matches/like` | Отправить лайк |
| POST | `/api/matches/dislike` | Отправить дизлайк |
| POST | `/api/matches/super-like` | Super-like |

**Тело JSON для POST like/dislike/super-like** (`internal/model/match.go`, тип `LikeRequest`):

```json
{
  "targetUserId": "<uuid или внутренний id пользователя>",
  "eventId": "<опционально, привязка к событию>"
}
```

Поле `targetUserId` обязательно (`binding:"required"`). Сервер запрещает действие на самого себя.

### Прочее

- `GET /health` — без авторизации, JSON со статусом сервиса.
- После успешных действий матчинга может вызываться логика push (FCM) через `service.NewFCMPushNotifier` — детали в `internal/service`.

---

## 6.3 upload-service

**Каталог:** `services/upload-service/`  
**Точка входа:** `cmd/main.go`  
**Порт по умолчанию:** `8006` (`PORT`)

### Конфигурация (`internal/config/config.go`)

| Переменная | По умолчанию в коде | В Docker Compose (типично) |
|------------|---------------------|------------------------------|
| `PORT` | 8006 | 8006 |
| `DB_HOST` | localhost | postgres |
| `DB_PORT` | 5432 | 5432 |
| `DB_USER` | andexadmin | andexevents |
| `DB_PASSWORD` | andexevents | andexevents_dev_password |
| `DB_NAME` | andexevents | andexevents |
| `DB_SSL_MODE` | disable | disable |
| `MINIO_ENDPOINT` | localhost:9000 | minio:9000 |
| `MINIO_ACCESS_KEY` | andexevents | andexevents |
| `MINIO_SECRET_KEY` | andexevents_minio_secret | andexevents_minio_secret |
| `MINIO_USE_SSL` | false | 0 |
| `FIREBASE_CREDENTIALS_FILE` | "" | /app/firebase-credentials.json |
| `FIREBASE_PROJECT_ID` | "" | из env |
| `UPLOADS_PUBLIC_BASE_URL` | "" | http://localhost или переопределение |

### Маршруты

**Публично (без Firebase middleware):**

| Метод | Путь | Назначение |
|-------|------|------------|
| GET | `/health` | Проверка живости |
| GET | `/uploads/:bucket/:userId/:filename` | Выдача файла из MinIO (handler `UploadsHandler.GetUpload`) |

**Защищённые (Firebase middleware на группе):**

Базовый префикс в приложении: **`/api/upload`** (совместимость с прежним Node API).

| Метод | Путь | Назначение |
|-------|------|------------|
| POST | `/api/upload` | Загрузка файла (`multipart/form-data`, поле **`file`**) |
| DELETE | `/api/upload` | Удаление фото из профиля (логика зависит от query-параметров) |

**Query для POST `/api/upload`:**

- `bucket` — необязательный; если пусто, по умолчанию **`events`**. Допустимые значения на стороне сервера (`AllowedBucket`): **`avatars`**, **`events`**, **`photos`** (см. `internal/storage/minio.go`). Иные значения → 400 `Invalid bucket name`.

**Ограничения размера (из `upload_handler.go`):**

- общий максимум по умолчанию **10 MiB** на файл;
- для `avatars` — **5 MiB**.

**Расширения:** `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp` (проверка расширения + sniff первых байтов для content-type).

**Путь объекта в MinIO:** `{firebaseUid}/{сгенерированное_имя_файла}` внутри выбранного бакета (для хранения используется Firebase UID, не внутренний numeric id).

**Побочные эффекты POST:**

- для `avatars` — попытка обновить `photoUrl` пользователя в БД;
- для `photos` — попытка добавить фото в коллекцию пользователя;
- ошибки БД при этом **не отменяют** успешную загрузку в MinIO (поведение сознательно «как у старого Node»).

**Ответ успеха** — тип `UploadResponse` (`internal/handler/types.go`):

```json
{
  "success": true,
  "fileUrl": "<URL>",
  "file": {
    "name": "<filename>",
    "size": <bytes>,
    "bucket": "<bucket>"
  }
}
```

**DELETE `/api/upload`:** обязательные query-параметры включают **`url`** (полный URL фото); **`bucket`** по умолчанию `photos`. Для `photos` вызывается удаление записи в БД через `userRepo.RemoveUserPhoto`.

---

## 6.4 Сборка и тесты

```bash
cd services/match-service && go build -o match-service ./cmd/main.go
cd services/upload-service && go build -o upload-service ./cmd/main.go
```

```bash
cd services/match-service && go test ./...
cd services/upload-service && go test ./...
```
