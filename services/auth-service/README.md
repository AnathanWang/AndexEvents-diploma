# Auth Service

Микросервис аутентификации и управления пользователями для AndexEvents.

## 🚀 Технологии

- **Go 1.21+** - язык программирования
- **Gin** - HTTP веб-фреймворк
- **Firebase Admin SDK** - аутентификация
- **pgx/v5** - PostgreSQL драйвер
- **Zap** - структурное логирование
- **testify** - тестирование с моками

## 📁 Структура проекта

```
auth-service/
├── cmd/
│   └── main.go              # Точка входа приложения
├── internal/
│   ├── config/              # Конфигурация приложения
│   ├── handler/             # HTTP handlers (контроллеры)
│   │   ├── user.go          # User endpoints
│   │   └── user_test.go     # Тесты handlers
│   ├── middleware/          # HTTP middleware
│   │   ├── auth.go          # Firebase аутентификация
│   │   └── auth_test.go     # Тесты middleware
│   ├── model/               # Модели данных
│   │   └── user.go          # User модель и DTO
│   ├── repository/          # Слой доступа к данным
│   │   └── user.go          # PostgreSQL репозиторий
│   └── service/             # Бизнес-логика
│       ├── user.go          # User сервис
│       └── user_test.go     # Тесты сервиса
├── go.mod
├── go.sum
└── README.md
```

## 🛠️ Локальный запуск

### Требования

- Go 1.21+
- PostgreSQL с PostGIS
- Firebase Service Account JSON

### Переменные окружения

```bash
# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CREDENTIALS_FILE=./secrets/firebase-service-account.json

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=andexadmin
DB_PASSWORD=andexevents
DB_NAME=andexevents

# Server
PORT=8001
```

### Запуск

```bash
# Из корня проекта
cd services/auth-service

# Установка зависимостей
go mod download

# Запуск
go run cmd/main.go
```

## 🧪 Тестирование

```bash
# Все тесты
go test ./... -v

# С покрытием
go test ./... -cover

# Конкретный пакет
go test ./internal/service/... -v
```

## 📡 API Endpoints

### Public

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/health` | Health check |
| POST | `/api/users` | Регистрация пользователя |

### Protected (требуют Firebase токен)

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/api/users/me` | Получить профиль |
| PUT | `/api/users/me` | Обновить профиль |
| PUT | `/api/users/me/location` | Обновить геолокацию |
| POST | `/api/users/me/onboarding` | Завершить онбординг |
| GET | `/api/users/matches` | Получить мэтчи поблизости |
| GET | `/api/users/:id` | Получить пользователя по ID |

### Примеры запросов

```bash
# Health check
curl http://localhost:8001/health

# Создать пользователя
curl -X POST http://localhost:8001/api/users \
  -H "Content-Type: application/json" \
  -d '{"firebaseUid": "uid123", "email": "user@example.com"}'

# Получить профиль (с токеном)
curl http://localhost:8001/api/users/me \
  -H "Authorization: Bearer <firebase-token>"

# Обновить геолокацию
curl -X PUT http://localhost:8001/api/users/me/location \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"latitude": 55.7558, "longitude": 37.6173}'

# Получить мэтчи
curl "http://localhost:8001/api/users/matches?radiusKm=50&limit=20" \
  -H "Authorization: Bearer <token>"
```

## 🏗️ Архитектура

Сервис следует **Clean Architecture**:

```
HTTP Request
     │
     ▼
┌─────────────┐
│  Handler    │ ← Обработка HTTP, валидация, response
└─────────────┘
     │
     ▼
┌─────────────┐
│  Service    │ ← Бизнес-логика
└─────────────┘
     │
     ▼
┌─────────────┐
│ Repository  │ ← Работа с БД
└─────────────┘
     │
     ▼
  PostgreSQL
```

**Преимущества:**
- Легко тестировать (моки на уровне интерфейсов)
- Легко менять реализацию (например, поменять БД)
- Понятное разделение ответственности
