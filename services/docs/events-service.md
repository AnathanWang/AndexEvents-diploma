# Events Service

Events-service — микросервис для управления событиями в приложении AndexEvents. Написан на Go с использованием чистой архитектуры.

## Обзор

Сервис предоставляет полный CRUD для событий, управление участниками, геопространственный поиск через PostGIS и интеграцию с Firebase для аутентификации.

## Технологии

| Технология | Версия | Назначение |
|------------|--------|------------|
| **Go** | 1.21+ | Язык программирования |
| **Gin** | v1.9+ | HTTP фреймворк |
| **pgx/v5** | v5.5+ | PostgreSQL драйвер |
| **PostGIS** | 3.0+ | Геопространственные запросы |
| **Firebase Admin SDK** | v4 | Аутентификация |
| **Zap** | v1.26+ | Структурированное логирование |
| **Testify** | v1.8+ | Тестирование и моки |
| **UUID** | google/uuid | Генерация идентификаторов |

## Структура проекта

```
events-service/
├── cmd/
│   └── main.go                    # Точка входа, инициализация DI
├── internal/
│   ├── config/
│   │   └── config.go              # Загрузка конфигурации из ENV
│   ├── handler/
│   │   ├── event_handler.go       # HTTP handlers для событий
│   │   └── event_handler_test.go  # Unit тесты handlers
│   ├── middleware/
│   │   ├── auth.go                # Firebase JWT аутентификация
│   │   ├── cors.go                # CORS политики
│   │   └── logger.go              # Zap логирование запросов
│   ├── model/
│   │   └── event.go               # Модели данных и DTO
│   ├── repository/
│   │   ├── event_repository.go        # Data Access для событий
│   │   └── participant_repository.go  # Data Access для участников
│   └── service/
│       ├── event_service.go       # Бизнес-логика
│       └── event_service_test.go  # Unit тесты сервиса
├── go.mod
└── go.sum
```

## API Endpoints

### События

| Method | Endpoint | Auth | Описание |
|--------|----------|------|----------|
| `GET` | `/api/events` | ❌ | Список событий с фильтрацией и пагинацией |
| `GET` | `/api/events/:id` | ❌ | Получить событие по ID |
| `GET` | `/api/events/user/:userId` | ❌ | События созданные пользователем |
| `POST` | `/api/events` | ✅ | Создать новое событие |
| `PUT` | `/api/events/:id` | ✅ | Обновить событие (только владелец) |
| `DELETE` | `/api/events/:id` | ✅ | Удалить событие (только владелец) |

### Участие в событиях

| Method | Endpoint | Auth | Описание |
|--------|----------|------|----------|
| `GET` | `/api/events/:id/participants` | ❌ | Список участников события |
| `POST` | `/api/events/:id/participate` | ✅ | Присоединиться к событию |
| `DELETE` | `/api/events/:id/participate` | ✅ | Покинуть событие |

### Служебные

| Method | Endpoint | Описание |
|--------|----------|----------|
| `GET` | `/health` | Health check для мониторинга |

## Модели данных

### Event

```go
type Event struct {
    ID              string       `json:"id"`
    Title           string       `json:"title"`
    Description     *string      `json:"description,omitempty"`
    Category        string       `json:"category"`
    Location        *string      `json:"location,omitempty"`
    Latitude        *float64     `json:"latitude,omitempty"`
    Longitude       *float64     `json:"longitude,omitempty"`
    DateTime        time.Time    `json:"dateTime"`
    EndDateTime     *time.Time   `json:"endDateTime,omitempty"`
    Price           *float64     `json:"price,omitempty"`
    ImageURL        *string      `json:"imageUrl,omitempty"`
    IsOnline        bool         `json:"isOnline"`
    Status          EventStatus  `json:"status"`
    MaxParticipants *int         `json:"maxParticipants,omitempty"`
    MinAge          *int         `json:"minAge,omitempty"`
    MaxAge          *int         `json:"maxAge,omitempty"`
    CreatedByID     string       `json:"createdById"`
    CreatedAt       time.Time    `json:"createdAt"`
    UpdatedAt       time.Time    `json:"updatedAt"`
    Creator         *EventCreator `json:"creator,omitempty"`
    Distance        *float64     `json:"distance,omitempty"` // Для геопоиска
}
```

### Participant

```go
type Participant struct {
    ID        string            `json:"id"`
    EventID   string            `json:"eventId"`
    UserID    string            `json:"userId"`
    Status    ParticipantStatus `json:"status"`
    JoinedAt  time.Time         `json:"joinedAt"`
    CreatedAt time.Time         `json:"createdAt"`
    UpdatedAt time.Time         `json:"updatedAt"`
}
```

### ParticipantWithUser (для JOIN запросов)

```go
type ParticipantWithUser struct {
    EventID  string            `json:"eventId"`
    UserID   string            `json:"userId"`
    Status   ParticipantStatus `json:"status"`
    JoinedAt time.Time         `json:"joinedAt"`
    Name     string            `json:"name"`
    Email    string            `json:"email"`
    PhotoURL *string           `json:"photoUrl,omitempty"`
}
```

### EventStatus

```go
const (
    EventStatusPending  EventStatus = "PENDING"   // Ожидает модерации
    EventStatusApproved EventStatus = "APPROVED"  // Одобрено
    EventStatusRejected EventStatus = "REJECTED"  // Отклонено
)
```

### ParticipantStatus

```go
const (
    ParticipantStatusInterested ParticipantStatus = "INTERESTED" // Интересуется
    ParticipantStatusGoing      ParticipantStatus = "GOING"      // Точно идёт
)
```

### Request/Response DTOs

```go
// Создание события
type CreateEventRequest struct {
    Title           string      `json:"title" binding:"required,min=3,max=200"`
    Description     *string     `json:"description,omitempty"`
    Category        string      `json:"category" binding:"required"`
    Location        *string     `json:"location,omitempty"`
    Latitude        *float64    `json:"latitude,omitempty"`
    Longitude       *float64    `json:"longitude,omitempty"`
    DateTime        time.Time   `json:"dateTime" binding:"required"`
    EndDateTime     *time.Time  `json:"endDateTime,omitempty"`
    Price           *float64    `json:"price,omitempty"`
    ImageURL        *string     `json:"imageUrl,omitempty"`
    IsOnline        bool        `json:"isOnline"`
    MaxParticipants *int        `json:"maxParticipants,omitempty"`
    MinAge          *int        `json:"minAge,omitempty"`
    MaxAge          *int        `json:"maxAge,omitempty"`
}

// Пагинированный ответ
type PaginatedEventsResponse struct {
    Events     []Event `json:"events"`
    Total      int     `json:"total"`
    Page       int     `json:"page"`
    PageSize   int     `json:"pageSize"`
    TotalPages int     `json:"totalPages"`
}

// Запрос списка событий
type GetEventsRequest struct {
    Page      int          `form:"page,default=1"`
    PageSize  int          `form:"pageSize,default=20"`
    Category  string       `form:"category"`
    Status    *EventStatus `form:"status"`
    IsOnline  *bool        `form:"isOnline"`
    Latitude  *float64     `form:"lat"`       // Для геопоиска
    Longitude *float64     `form:"lon"`       // Для геопоиска
    Radius    *float64     `form:"radius"`    // В метрах
    Search    string       `form:"search"`    // Полнотекстовый поиск
    SortBy    string       `form:"sortBy,default=dateTime"`
    SortOrder string       `form:"sortOrder,default=asc"`
}
```

## Примеры запросов

### Создание события

```bash
curl -X POST http://localhost:8002/api/events \
  -H "Authorization: Bearer <firebase_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Футбол в парке",
    "category": "sports",
    "description": "Дружеский матч по футболу",
    "location": "Парк Горького",
    "latitude": 55.7312,
    "longitude": 37.6031,
    "dateTime": "2026-02-01T15:00:00Z",
    "maxParticipants": 22,
    "isOnline": false
  }'
```

**Ответ (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Футбол в парке",
  "category": "sports",
  "description": "Дружеский матч по футболу",
  "location": "Парк Горького",
  "latitude": 55.7312,
  "longitude": 37.6031,
  "dateTime": "2026-02-01T15:00:00Z",
  "status": "APPROVED",
  "maxParticipants": 22,
  "isOnline": false,
  "createdById": "user-123",
  "createdAt": "2026-01-28T10:00:00Z",
  "updatedAt": "2026-01-28T10:00:00Z"
}
```

### Получение списка событий с фильтрацией

```bash
curl "http://localhost:8002/api/events?page=1&pageSize=10&category=sports&sortBy=dateTime&sortOrder=asc"
```

**Ответ (200 OK):**
```json
{
  "events": [...],
  "total": 45,
  "page": 1,
  "pageSize": 10,
  "totalPages": 5
}
```

### Геопоиск событий поблизости (PostGIS)

```bash
curl "http://localhost:8002/api/events?lat=55.75&lon=37.61&radius=5000"
```

**Параметры:**
- `lat` — широта центра поиска
- `lon` — долгота центра поиска  
- `radius` — радиус поиска в метрах (по умолчанию 10000)

**Ответ включает расстояние до каждого события:**
```json
{
  "events": [
    {
      "id": "event-123",
      "title": "Концерт в парке",
      "distance": 1234.56,
      ...
    }
  ],
  "total": 15,
  ...
}
```

### Получение события по ID

```bash
curl http://localhost:8002/api/events/550e8400-e29b-41d4-a716-446655440000
```

**Ответ (200 OK):**
```json
{
  "event": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Футбол в парке",
    ...
  },
  "participantCount": 12,
  "creator": {
    "id": "user-123",
    "name": "Иван Иванов",
    "email": "ivan@example.com",
    "photoUrl": "https://..."
  }
}
```

### Присоединение к событию

```bash
curl -X POST http://localhost:8002/api/events/event-123/participate \
  -H "Authorization: Bearer <firebase_token>"
```

**Ответ (200 OK):**
```json
{
  "message": "successfully joined event"
}
```

### Получение участников события

```bash
curl "http://localhost:8002/api/events/event-123/participants?page=1&pageSize=20"
```

**Ответ (200 OK):**
```json
{
  "participants": [
    {
      "eventId": "event-123",
      "userId": "user-456",
      "status": "GOING",
      "joinedAt": "2026-01-28T12:00:00Z",
      "name": "Пётр Петров",
      "email": "petr@example.com",
      "photoUrl": "https://..."
    }
  ],
  "total": 12,
  "page": 1,
  "pageSize": 20,
  "totalPages": 1
}
```

### Покинуть событие

```bash
curl -X DELETE http://localhost:8002/api/events/event-123/participate \
  -H "Authorization: Bearer <firebase_token>"
```

**Ответ (200 OK):**
```json
{
  "message": "successfully left event"
}
```

## Конфигурация

### Переменные окружения

| Переменная | Описание | По умолчанию | Обязательная |
|------------|----------|--------------|--------------|
| `PORT` | Порт HTTP сервера | `8002` | ❌ |
| `ENVIRONMENT` | Окружение (development/production) | `development` | ❌ |
| `DB_HOST` | Хост PostgreSQL | `localhost` | ❌ |
| `DB_PORT` | Порт PostgreSQL | `5432` | ❌ |
| `DB_USER` | Пользователь БД | `andexadmin` | ❌ |
| `DB_PASSWORD` | Пароль БД | `andexevents` | ❌ |
| `DB_NAME` | Имя базы данных | `andexevents` | ❌ |
| `FIREBASE_PROJECT_ID` | Firebase Project ID | - | ✅ |
| `FIREBASE_CREDENTIALS_FILE` | Путь к Firebase credentials JSON | - | ✅ |

### Пример .env файла

```env
PORT=8002
ENVIRONMENT=development
DB_HOST=localhost
DB_PORT=5432
DB_USER=andexadmin
DB_PASSWORD=andexevents
DB_NAME=andexevents
FIREBASE_PROJECT_ID=andexevents
FIREBASE_CREDENTIALS_FILE=../../secrets/firebase-service-account.json
```

## Запуск

### Локальная разработка

```bash
# Перейти в директорию сервиса
cd services/events-service

# Установить зависимости
go mod tidy

# Запустить сервис
FIREBASE_PROJECT_ID=andexevents \
FIREBASE_CREDENTIALS_FILE=../../secrets/firebase-service-account.json \
go run cmd/main.go
```

### С переменными окружения

```bash
export FIREBASE_PROJECT_ID=andexevents
export FIREBASE_CREDENTIALS_FILE=../../secrets/firebase-service-account.json
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=andexadmin
export DB_PASSWORD=andexevents
export DB_NAME=andexevents

go run cmd/main.go
```

### Docker

```bash
# Собрать образ
docker build -t events-service -f services/events-service/Dockerfile .

# Запустить контейнер
docker run -p 8002:8002 \
  -e DB_HOST=host.docker.internal \
  -e FIREBASE_PROJECT_ID=your-project \
  -e FIREBASE_CREDENTIALS_FILE=/app/credentials.json \
  -v $(pwd)/secrets/firebase-service-account.json:/app/credentials.json \
  events-service
```

### Проверка работоспособности

```bash
# Health check
curl http://localhost:8002/health

# Ответ
{"service":"events-service","status":"healthy"}
```

## Тестирование

```bash
cd services/events-service

# Запустить все тесты
go test ./...

# С подробным выводом
go test -v ./...

# С покрытием кода
go test -cover ./...

# Тесты конкретного пакета
go test -v ./internal/service/...
go test -v ./internal/handler/...

# Генерация отчёта о покрытии
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### Структура тестов

- `internal/handler/event_handler_test.go` — тесты HTTP handlers с моками сервиса
- `internal/service/event_service_test.go` — тесты бизнес-логики с моками репозиториев

Используется библиотека **testify** для:
- `mock` — создание моков интерфейсов
- `assert` — проверка утверждений

## PostGIS — геопространственные запросы

Сервис использует расширение PostGIS для работы с геоданными.

### Используемые функции

| Функция | Описание |
|---------|----------|
| `ST_MakePoint(lon, lat)` | Создание точки из координат |
| `ST_SetSRID(..., 4326)` | Установка системы координат WGS84 |
| `::geography` | Приведение к географическому типу |
| `ST_DWithin(geo1, geo2, distance)` | Проверка нахождения в радиусе |
| `ST_Distance(geo1, geo2)` | Расчёт расстояния в метрах |

### Создание события с координатами

```sql
INSERT INTO "Event" (..., latitude, longitude, "locationGeo", ...)
VALUES (
    ...,
    55.7312,  -- latitude
    37.6031,  -- longitude
    ST_SetSRID(ST_MakePoint(37.6031, 55.7312), 4326)::geography,
    ...
);
```

### Поиск событий в радиусе

```sql
SELECT 
    *,
    ST_Distance(
        "locationGeo",
        ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography
    ) as distance
FROM "Event"
WHERE "locationGeo" IS NOT NULL
AND ST_DWithin(
    "locationGeo", 
    ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography, 
    10000  -- 10 км в метрах
)
ORDER BY distance ASC;
```

### Индекс для ускорения геопоиска

```sql
CREATE INDEX idx_event_location_geo ON "Event" USING GIST ("locationGeo");
```

## Обработка ошибок

### HTTP коды ответов

| Код | Статус | Описание |
|-----|--------|----------|
| `200` | OK | Успешный запрос |
| `201` | Created | Ресурс создан |
| `204` | No Content | Успешное удаление |
| `400` | Bad Request | Невалидные данные запроса |
| `401` | Unauthorized | Требуется аутентификация |
| `403` | Forbidden | Нет прав на операцию |
| `404` | Not Found | Ресурс не найден |
| `500` | Internal Server Error | Внутренняя ошибка сервера |

### Ошибки сервисного слоя

```go
var (
    ErrEventNotFound      = errors.New("event not found")
    ErrNotEventOwner      = errors.New("not event owner")
    ErrAlreadyParticipant = errors.New("already a participant")
    ErrNotParticipant     = errors.New("not a participant")
    ErrEventFull          = errors.New("event is full")
)
```

### Формат ошибки

```json
{
  "error": "event not found"
}
```

## Архитектура

### Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      HTTP Layer                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   Handlers (event_handler.go)                       │   │
│  │   - Парсинг запросов                                │   │
│  │   - Валидация входных данных                        │   │
│  │   - Формирование HTTP ответов                       │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   Services (event_service.go)                       │   │
│  │   - Бизнес-логика                                   │   │
│  │   - Валидация бизнес-правил                         │   │
│  │   - Оркестрация репозиториев                        │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   Repository Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   Repositories (event_repository.go)                │   │
│  │   - SQL запросы                                     │   │
│  │   - Маппинг данных                                  │   │
│  │   - Работа с PostGIS                                │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Database Layer                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   PostgreSQL + PostGIS                              │   │
│  │   - Таблицы: Event, Participant, User               │   │
│  │   - Геопространственные индексы                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Injection

Зависимости инжектируются через конструкторы:

```go
// main.go
eventRepo := repository.NewEventRepository(pool)
participantRepo := repository.NewParticipantRepository(pool)
eventService := service.NewEventService(eventRepo, participantRepo)
eventHandler := handler.NewEventHandler(eventService)
```

### Интерфейсы

Все слои взаимодействуют через интерфейсы для тестируемости:

```go
// Repository interface
type EventRepository interface {
    Create(ctx context.Context, event *model.Event) error
    GetByID(ctx context.Context, id string) (*model.Event, error)
    GetAll(ctx context.Context, req *model.GetEventsRequest) ([]model.Event, int, error)
    // ...
}

// Service interface
type EventService interface {
    CreateEvent(ctx context.Context, userID string, req *model.CreateEventRequest) (*model.Event, error)
    GetEventByID(ctx context.Context, id string) (*model.EventResponse, error)
    // ...
}
```

## Связанные сервисы

| Сервис | Порт | Описание |
|--------|------|----------|
| **auth-service** | 8001 | Аутентификация и управление пользователями |
| **events-service** | 8002 | Управление событиями (текущий) |

## База данных

### Таблица Event

```sql
CREATE TABLE "Event" (
    id TEXT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    location TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    "locationGeo" geography(POINT, 4326),
    "dateTime" TIMESTAMP WITH TIME ZONE NOT NULL,
    "endDateTime" TIMESTAMP WITH TIME ZONE,
    price DECIMAL(10, 2),
    "imageUrl" TEXT,
    "isOnline" BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'APPROVED',
    "maxParticipants" INTEGER,
    "minAge" INTEGER,
    "maxAge" INTEGER,
    "createdById" TEXT REFERENCES "User"(id),
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индексы
CREATE INDEX idx_event_category ON "Event"(category);
CREATE INDEX idx_event_status ON "Event"(status);
CREATE INDEX idx_event_created_by ON "Event"("createdById");
CREATE INDEX idx_event_date_time ON "Event"("dateTime");
CREATE INDEX idx_event_location_geo ON "Event" USING GIST ("locationGeo");
```

### Таблица Participant

```sql
CREATE TABLE "Participant" (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "eventId" TEXT NOT NULL REFERENCES "Event"(id) ON DELETE CASCADE,
    "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'GOING',
    "joinedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE("eventId", "userId")
);

CREATE INDEX idx_participant_event ON "Participant"("eventId");
CREATE INDEX idx_participant_user ON "Participant"("userId");
```

## Middleware

### AuthMiddleware

Проверяет Firebase JWT токен из заголовка `Authorization: Bearer <token>`:

```go
func AuthMiddleware(authClient *auth.Client) gin.HandlerFunc {
    return func(c *gin.Context) {
        token := extractToken(c.GetHeader("Authorization"))
        decodedToken, err := authClient.VerifyIDToken(ctx, token)
        if err != nil {
            c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
            return
        }
        c.Set("userID", decodedToken.UID)
        c.Next()
    }
}
```

### CORSMiddleware

Настраивает CORS для разрешения запросов с фронтенда.

### LoggerMiddleware

Логирует все HTTP запросы с помощью Zap.
