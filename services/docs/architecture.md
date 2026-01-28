# 🏗️ Архитектура Go Микросервисов

## 📋 Содержание

1. [Обзор архитектуры](#обзор-архитектуры)
2. [Структура проекта](#структура-проекта)
3. [Микросервисы](#микросервисы)
4. [Shared пакеты](#shared-пакеты)
5. [База данных](#база-данных)
6. [Аутентификация](#аутентификация)
7. [Коммуникация между сервисами](#коммуникация-между-сервисами)

---

## 🎯 Обзор архитектуры

### Высокоуровневая диаграмма

```
                                    ┌─────────────────┐
                                    │  Flutter App    │
                                    └────────┬────────┘
                                             │
                                             ▼
                              ┌──────────────────────────┐
                              │      API Gateway         │
                              │    (Future: Kong/Nginx)  │
                              └──────────────────────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    ▼                        ▼                        ▼
          ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
          │  Auth Service   │    │ Events Service  │    │ Upload Service  │
          │    :8001        │    │    :8002        │    │    :8004        │
          └────────┬────────┘    └────────┬────────┘    └────────┬────────┘
                   │                      │                      │
                   └──────────────────────┼──────────────────────┘
                                          │
                                          ▼
                              ┌──────────────────────────┐
                              │      PostgreSQL          │
                              │      + PostGIS           │
                              └──────────────────────────┘
                                          │
                              ┌───────────┴───────────┐
                              │                       │
                              ▼                       ▼
                    ┌─────────────────┐    ┌─────────────────┐
                    │     MinIO       │    │    Firebase     │
                    │   (Storage)     │    │     (Auth)      │
                    └─────────────────┘    └─────────────────┘
```

### Принципы архитектуры

| Принцип | Описание |
|---------|----------|
| **Microservices** | Каждый сервис отвечает за свой bounded context |
| **Database per Service** | Логическое разделение (сейчас одна БД, таблицы разделены) |
| **API First** | REST API с JSON |
| **12-Factor App** | Конфигурация через env, stateless сервисы |

---

## 📁 Структура проекта

```
andexevents/
├── services/                    # Go микросервисы
│   ├── auth-service/           # Аутентификация и пользователи
│   │   ├── cmd/main.go
│   │   └── internal/
│   ├── events-service/         # События (planned)
│   ├── match-service/          # Мэтчи (planned)
│   ├── upload-service/         # Загрузка файлов (planned)
│   └── docs/                   # Документация сервисов
│
├── shared/                      # Общие Go пакеты
│   └── pkg/
│       ├── database/           # Подключение к PostgreSQL
│       ├── firebase/           # Firebase Admin SDK
│       ├── logger/             # Zap logger
│       ├── response/           # Стандартные HTTP ответы
│       └── validator/          # Валидация запросов
│
├── lib/                        # Flutter приложение
├── backend/                    # Legacy Express.js (deprecated)
├── secrets/                    # Credentials (git ignored)
└── docs/                       # Общая документация
```

---

## 🔧 Микросервисы

### Auth Service (порт 8001) ✅ Готов

**Ответственность:**
- Регистрация/аутентификация через Firebase
- Управление профилями пользователей
- Геолокация пользователей
- Поиск мэтчей

**Эндпоинты:**
```
POST   /api/users
GET    /api/users/me
PUT    /api/users/me
PUT    /api/users/me/location
POST   /api/users/me/onboarding
GET    /api/users/matches
GET    /api/users/:id
```

### Events Service (порт 8002) 📋 Planned

**Ответственность:**
- CRUD операции для событий
- Геопоиск событий
- Управление участниками
- Рекомендации событий

**Эндпоинты:**
```
POST   /api/events
GET    /api/events
GET    /api/events/:id
PUT    /api/events/:id
DELETE /api/events/:id
GET    /api/events/nearby
POST   /api/events/:id/join
DELETE /api/events/:id/leave
GET    /api/events/:id/participants
```

### Match Service (порт 8003) 📋 Planned

**Ответственность:**
- Лайки/дизлайки
- Определение мэтчей
- История мэтчей

### Upload Service (порт 8004) 📋 Planned

**Ответственность:**
- Загрузка изображений в MinIO
- Генерация thumbnails
- Управление файлами

---

## 📦 Shared пакеты

### database

Подключение к PostgreSQL через pgx:

```go
import "github.com/AnathanWang/andexevents/shared/pkg/database"

pool, err := database.NewPool(ctx, cfg)
```

### firebase

Инициализация Firebase Admin SDK:

```go
import "github.com/AnathanWang/andexevents/shared/pkg/firebase"

client, err := firebase.NewClient(ctx, projectID, credentialsFile)
token, err := client.VerifyIDToken(ctx, idToken)
```

### logger

Структурированное логирование:

```go
import "github.com/AnathanWang/andexevents/shared/pkg/logger"

log := logger.New()
log.Info("User created", zap.String("userID", id))
```

### response

Стандартизированные HTTP ответы:

```go
import "github.com/AnathanWang/andexevents/shared/pkg/response"

response.Success(c, data)           // 200
response.Created(c, data)           // 201
response.BadRequest(c, "message")   // 400
response.Unauthorized(c, "message") // 401
response.NotFound(c, "message")     // 404
response.Conflict(c, "message")     // 409
response.InternalError(c, "message") // 500
```

### validator

Валидация структур:

```go
import "github.com/AnathanWang/andexevents/shared/pkg/validator"

if err := validator.Validate(&req); err != nil {
    response.ValidationError(c, err)
    return
}
```

---

## 🗄️ База данных

### PostgreSQL + PostGIS

**Текущие таблицы (Prisma schema):**

```sql
-- Пользователи
"User" (
    id UUID PRIMARY KEY,
    "supabaseUid" TEXT UNIQUE,  -- Firebase UID
    email TEXT UNIQUE,
    "displayName" TEXT,
    bio TEXT,
    age INTEGER,
    "avatarUrl" TEXT,
    interests TEXT[],
    "lastLatitude" DOUBLE PRECISION,
    "lastLongitude" DOUBLE PRECISION,
    "isOnboardingCompleted" BOOLEAN,
    "createdAt" TIMESTAMP,
    "updatedAt" TIMESTAMP
)

-- События
"Event" (...)

-- Участники событий
"EventParticipant" (...)

-- Мэтчи
"Match" (...)
```

### Геопоиск

Используется простой bounding box для поиска в радиусе:

```go
// Вычисление границ для поиска
latDelta := float64(radiusKm) / 111.0
lonDelta := float64(radiusKm) / (111.0 * math.Cos(lat*math.Pi/180))

minLat := lat - latDelta
maxLat := lat + latDelta
minLon := lon - lonDelta
maxLon := lon + lonDelta
```

---

## 🔐 Аутентификация

### Flow

```
┌──────────────┐    1. Login/Register    ┌──────────────┐
│              │ ───────────────────────▶│              │
│   Flutter    │                         │   Firebase   │
│     App      │◀─────────────────────── │     Auth     │
│              │    2. ID Token          │              │
└──────────────┘                         └──────────────┘
       │
       │ 3. API Request + Bearer Token
       ▼
┌──────────────┐    4. Verify Token      ┌──────────────┐
│              │ ───────────────────────▶│              │
│ Auth Service │                         │   Firebase   │
│              │◀─────────────────────── │  Admin SDK   │
│              │    5. Token Claims      │              │
└──────────────┘                         └──────────────┘
       │
       │ 6. firebase_uid in context
       ▼
┌──────────────┐
│   Handler    │
└──────────────┘
```

### Middleware

```go
func AuthMiddleware(firebaseClient *firebase.Client) gin.HandlerFunc {
    return func(c *gin.Context) {
        // 1. Извлечь токен из Authorization: Bearer <token>
        // 2. Верифицировать через Firebase Admin SDK
        // 3. Добавить firebase_uid в context
        c.Set("firebase_uid", token.UID)
        c.Next()
    }
}
```

---

## 🔗 Коммуникация между сервисами

### Текущий подход: Direct HTTP

Сервисы общаются напрямую через HTTP:

```go
// Пример: Events Service вызывает Auth Service
resp, err := http.Get("http://auth-service:8001/api/users/" + userID)
```

### Будущее: Service Mesh / Message Queue

При масштабировании можно добавить:
- **gRPC** для внутренней коммуникации
- **RabbitMQ/Kafka** для асинхронных событий
- **Service Mesh** (Istio) для service discovery

---

## 🔧 Конфигурация сервисов

### Стандартные переменные

| Переменная | Описание |
|------------|----------|
| `PORT` | Порт сервиса |
| `DB_HOST`, `DB_PORT`, etc. | PostgreSQL |
| `FIREBASE_PROJECT_ID` | Firebase проект |
| `FIREBASE_CREDENTIALS_FILE` | Путь к service account |
| `LOG_LEVEL` | debug/info/warn/error |

### Docker Compose (planned)

```yaml
services:
  auth-service:
    build: ./services/auth-service
    ports:
      - "8001:8001"
    environment:
      - DB_HOST=postgres
      - FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
    depends_on:
      - postgres

  events-service:
    build: ./services/events-service
    ports:
      - "8002:8002"
    depends_on:
      - postgres
      - auth-service
```

---

## 📊 Мониторинг (Planned)

### Метрики

- Prometheus для сбора метрик
- Grafana для визуализации

### Трейсинг

- OpenTelemetry для distributed tracing
- Jaeger для визуализации traces

### Логирование

- Структурированные JSON логи
- ELK Stack или Loki для агрегации
