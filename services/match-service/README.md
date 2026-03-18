# Match Service

Микросервис лайков/дизлайков и взаимных матчей (Tinder-style) для AndexEvents.

## 🚀 API

Все endpoints защищены Supabase JWT (Bearer token) и требуют, чтобы пользователь уже существовал в таблице `"User"` (иначе `dbUserID` не будет найден).

| Метод | Endpoint | Описание |
|------:|----------|----------|
| GET | `/health` | Health check |
| GET | `/api/matches` | Мои взаимные матчи (возвращает пользователей) |
| GET | `/api/matches/actions?action=LIKE\|DISLIKE\|SUPER_LIKE&limit=50` | Пользователи, по которым я делал действие |
| POST | `/api/matches/like` | Лайк `{ "targetUserId": "..." }` |
| POST | `/api/matches/dislike` | Дизлайк `{ "targetUserId": "..." }` |
| POST | `/api/matches/super-like` | Супер-лайк `{ "targetUserId": "..." }` |

## 🛠️ Локальный запуск

Переменные окружения:

```bash
DB_HOST=localhost
DB_PORT=5432
DB_USER=andexevents
DB_PASSWORD=andexevents_dev_password
DB_NAME=andexevents

SUPABASE_JWT_SECRET=... # ваш секрет

PORT=8005
ENVIRONMENT=development
```

Запуск:

```bash
cd services/match-service
go mod download
go run cmd/main.go
```

Тесты:

```bash
go test ./... -v
```
