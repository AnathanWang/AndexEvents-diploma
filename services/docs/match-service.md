# 🎯 Match Service

Микросервис лайков/дизлайков и взаимных мэтчей (Tinder-style).

Реализует тот же API-формат, что и legacy Node.js роутер `backend/src/routes/match.routes.ts`:

- `GET /api/matches`
- `GET /api/matches/actions`
- `POST /api/matches/like`
- `POST /api/matches/dislike`
- `POST /api/matches/super-like`

## 🔐 Аутентификация

Все endpoints защищены **Supabase JWT**.

```http
Authorization: Bearer <supabase-jwt>
```

Важно: middleware пытается найти пользователя в БД по `"User"."supabaseUid"`. Если пользователь не найден, handlers вернут `401` с сообщением `"Unauthorized: User ID not found"` (как в Node-контроллере, где `req.user.userId` может быть пустым).

## 🌍 Base URL

Локально:

- `http://localhost:8005`

## 📡 Endpoints

### Health

```http
GET /health
```

Response `200`:

```json
{
  "status": "healthy",
  "service": "match-service"
}
```

### Получить взаимные мэтчи

Возвращает список пользователей ("другая сторона" матча), чтобы клиент мог использовать существующую User-модель.

```http
GET /api/matches
Authorization: Bearer <token>
```

Response `200`:

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "supabaseUid": "...",
      "email": "...",
      "displayName": "..."
    }
  ]
}
```

### Получить мои действия

Аналог Node endpoint `GET /api/matches/actions?action=...&limit=...`.

```http
GET /api/matches/actions?action=LIKE|DISLIKE|SUPER_LIKE&limit=50
Authorization: Bearer <token>
```

Response `200`:

```json
{
  "success": true,
  "data": [
    { "id": "...", "displayName": "..." }
  ]
}
```

Ошибки:

- `400` если `action` не из `LIKE|DISLIKE|SUPER_LIKE`
- `401` если пользователь не определён

Примечание по совместимости с Node: `limit` применяется к последним действиям пользователя **до фильтрации по action** (как в Node-контроллере).

### Like / Dislike / Super-like

```http
POST /api/matches/like
Authorization: Bearer <token>
Content-Type: application/json

{ "targetUserId": "<uuid пользователя из таблицы User>" }
```

Аналогично для:

- `POST /api/matches/dislike`
- `POST /api/matches/super-like`

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "...",
    "userAId": "...",
    "userBId": "...",
    "userAAction": "LIKE",
    "userBAction": null,
    "isMutual": false,
    "matchedAt": null,
    "createdAt": "...",
    "updatedAt": "..."
  },
  "message": "Like sent!"
}
```

Ошибки:

- `400` если `targetUserId` не указан
- `400` если пользователь пытается поставить действие самому себе (`Cannot like yourself` / `Cannot dislike yourself` / `Cannot super like yourself`)
- `401` если пользователь не определён

## 🗄️ Используемые таблицы

- `"User"` (поиск пользователя по `supabaseUid`, отдаём публичные поля)
- `"Match"` (как в Prisma schema legacy backend)

## ⚙️ Переменные окружения

```bash
PORT=8005
ENVIRONMENT=development

DB_HOST=localhost
DB_PORT=5432
DB_USER=andexevents
DB_PASSWORD=andexevents_dev_password
DB_NAME=andexevents

SUPABASE_JWT_SECRET=...
```

## 🧪 Тестирование

```bash
cd services/match-service
go test ./... -v
```
