# Users Service

Users-service — микросервис для управления пользователями и профилями в приложении AndexEvents. Написан на Go с использованием чистой архитектуры.

## Обзор

Сервис предоставляет функционал создания и управления профилями пользователей, обновление геолокации, а также поиск потенциальных матчей на основе местоположения и возрастных предпочтений. Использует Supabase JWT для аутентификации.

## Технологии

| Технология | Версия | Назначение |
|------------|--------|------------|
| **Go** | 1.23+ | Язык программирования |
| **Gin** | v1.10+ | HTTP фреймворк |
| **pgx/v5** | v5.7+ | PostgreSQL драйвер |
| **golang-jwt/jwt** | v5 | JWT токены (Supabase) |
| **Zap** | v1.27+ | Структурированное логирование |
| **Testify** | v1.11+ | Тестирование и моки |
| **UUID** | google/uuid | Генерация идентификаторов |

## Структура проекта

```
users-service/
├── cmd/
│   └── main.go                    # Точка входа, инициализация DI
├── internal/
│   ├── config/
│   │   └── config.go              # Загрузка конфигурации из ENV
│   ├── handler/
│   │   └── user_handler.go        # HTTP handlers для пользователей
│   ├── middleware/
│   │   ├── auth.go                # Supabase JWT аутентификация
│   │   ├── cors.go                # CORS политики
│   │   └── logger.go              # Zap логирование запросов
│   ├── model/
│   │   └── user.go                # Модели данных и DTO
│   ├── repository/
│   │   └── user_repository.go     # Data Access для пользователей
│   └── service/
│       ├── user_service.go        # Бизнес-логика
│       └── user_service_test.go   # Unit тесты сервиса
├── go.mod
└── go.sum
```

## API Endpoints

### Пользователи

| Method | Endpoint | Auth | Описание |
|--------|----------|------|----------|
| `POST` | `/api/users` | ✅ | Создать профиль пользователя |
| `GET` | `/api/users/me` | ✅ | Получить профиль текущего пользователя |
| `PUT` | `/api/users/me` | ✅ | Обновить профиль пользователя |
| `PUT` | `/api/users/me/location` | ✅ | Обновить геолокацию |
| `GET` | `/api/users/matches` | ✅ | Найти потенциальные матчи |

### Служебные

| Method | Endpoint | Описание |
|--------|----------|----------|
| `GET` | `/health` | Health check для мониторинга |

## Модели данных

### User

```go
type User struct {
    ID                    string          `json:"id"`
    SupabaseUID           string          `json:"supabaseUid"`
    Email                 string          `json:"email"`
    DisplayName           *string         `json:"displayName,omitempty"`
    PhotoURL              *string         `json:"photoUrl,omitempty"`
    Bio                   *string         `json:"bio,omitempty"`
    Interests             []string        `json:"interests,omitempty"`
    SocialLinks           json.RawMessage `json:"socialLinks,omitempty"`
    Age                   *int            `json:"age,omitempty"`
    Gender                *string         `json:"gender,omitempty"`
    Role                  UserRole        `json:"role"`
    LastLatitude          *float64        `json:"lastLatitude,omitempty"`
    LastLongitude         *float64        `json:"lastLongitude,omitempty"`
    LastLocationUpdate    *time.Time      `json:"lastLocationUpdate,omitempty"`
    IsProfileVisible      bool            `json:"isProfileVisible"`
    IsLocationVisible     bool            `json:"isLocationVisible"`
    MinAge                *int            `json:"minAge,omitempty"`
    MaxAge                *int            `json:"maxAge,omitempty"`
    MaxDistance           int             `json:"maxDistance"`
    FCMToken              *string         `json:"fcmToken,omitempty"`
    IsOnboardingCompleted bool            `json:"isOnboardingCompleted"`
    CreatedAt             time.Time       `json:"createdAt"`
    UpdatedAt             time.Time       `json:"updatedAt"`
    Distance              *float64        `json:"distance,omitempty"` // вычисляемое
}
```

### UserRole

```go
const (
    UserRoleUser      UserRole = "USER"
    UserRoleModerator UserRole = "MODERATOR"
    UserRoleAdmin     UserRole = "ADMIN"
)
```

## Детальное описание API

### POST /api/users — Создание пользователя

Создаёт профиль пользователя на основе данных из Supabase JWT токена.

**Логика:**
1. Извлекает `sub` (supabaseUID) и `email` из JWT токена
2. Проверяет существование пользователя по email
3. Если пользователь существует и `supabaseUid` пустой — обновляет его
4. Если пользователь существует с таким же `supabaseUid` — возвращает его
5. Если пользователь существует с другим `supabaseUid` — возвращает ошибку конфликта
6. Иначе создаёт нового пользователя

**Request:**
```http
POST /api/users
Authorization: Bearer <supabase_jwt_token>
Content-Type: application/json

{
    "displayName": "Иван Иванов",
    "photoUrl": "https://example.com/photo.jpg"
}
```

**Response (201 Created):**
```json
{
    "success": true,
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "supabaseUid": "auth-uid-123",
        "email": "ivan@example.com",
        "displayName": "Иван Иванов",
        "role": "USER",
        "isProfileVisible": true,
        "isLocationVisible": true,
        "maxDistance": 50000,
        "isOnboardingCompleted": false,
        "createdAt": "2026-01-29T10:00:00Z",
        "updatedAt": "2026-01-29T10:00:00Z"
    }
}
```

**Ошибки:**
- `401 Unauthorized` — отсутствует или невалидный токен
- `409 Conflict` — пользователь с этим email уже существует с другим supabaseUid

---

### GET /api/users/me — Получить текущего пользователя

**Request:**
```http
GET /api/users/me
Authorization: Bearer <supabase_jwt_token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "supabaseUid": "auth-uid-123",
        "email": "ivan@example.com",
        "displayName": "Иван Иванов",
        "bio": "Люблю путешествия и музыку",
        "interests": ["travel", "music", "tech"],
        "age": 28,
        "gender": "male",
        "role": "USER",
        "lastLatitude": 55.7558,
        "lastLongitude": 37.6173,
        "isProfileVisible": true,
        "isLocationVisible": true,
        "isOnboardingCompleted": true,
        "createdAt": "2026-01-29T10:00:00Z",
        "updatedAt": "2026-01-29T12:30:00Z"
    }
}
```

**Ошибки:**
- `401 Unauthorized` — отсутствует токен или пользователь не найден в БД
- `404 Not Found` — профиль пользователя не существует

---

### PUT /api/users/me — Обновить профиль

**Request:**
```http
PUT /api/users/me
Authorization: Bearer <supabase_jwt_token>
Content-Type: application/json

{
    "displayName": "Иван Иванов",
    "bio": "Люблю путешествия и музыку",
    "age": 28,
    "gender": "male",
    "interests": ["travel", "music", "tech"],
    "socialLinks": {
        "telegram": "@ivan",
        "instagram": "ivan_ivanov"
    },
    "isOnboardingCompleted": true
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "displayName": "Иван Иванов",
        "bio": "Люблю путешествия и музыку",
        "age": 28,
        "gender": "male",
        "interests": ["travel", "music", "tech"],
        "socialLinks": {
            "telegram": "@ivan",
            "instagram": "ivan_ivanov"
        },
        "isOnboardingCompleted": true,
        "updatedAt": "2026-01-29T12:30:00Z"
    }
}
```

---

### PUT /api/users/me/location — Обновить геолокацию

**Request:**
```http
PUT /api/users/me/location
Authorization: Bearer <supabase_jwt_token>
Content-Type: application/json

{
    "latitude": 55.7558,
    "longitude": 37.6173
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "message": "Location updated successfully"
}
```

**Валидация:**
- `latitude`: от -90 до 90
- `longitude`: от -180 до 180

**Ошибки:**
- `400 Bad Request` — невалидные координаты

---

### GET /api/users/matches — Найти матчи

Ищет пользователей в заданном радиусе с учётом возрастных фильтров.

**Query параметры:**

| Параметр | Тип | Default | Описание |
|----------|-----|---------|----------|
| `latitude` | float | последняя известная | Широта центра поиска |
| `longitude` | float | последняя известная | Долгота центра поиска |
| `radiusKm` | float | 50 | Радиус поиска в километрах |
| `limit` | int | 20 | Максимальное количество результатов |

**Request:**
```http
GET /api/users/matches?latitude=55.7558&longitude=37.6173&radiusKm=30&limit=10
Authorization: Bearer <supabase_jwt_token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": [
        {
            "id": "user-id-1",
            "displayName": "Мария",
            "bio": "Фотограф",
            "age": 25,
            "interests": ["photo", "travel"],
            "lastLatitude": 55.7600,
            "lastLongitude": 37.6200,
            "distance": 1250.5
        },
        {
            "id": "user-id-2",
            "displayName": "Алексей",
            "bio": "Разработчик",
            "age": 30,
            "interests": ["tech", "music"],
            "lastLatitude": 55.7400,
            "lastLongitude": 37.6100,
            "distance": 2100.3
        }
    ]
}
```

**Логика фильтрации:**
1. Исключает текущего пользователя
2. Только пользователи с `isOnboardingCompleted = true`
3. Только пользователи с `isProfileVisible = true`
4. Только пользователи с известной локацией
5. Применяет возрастные фильтры текущего пользователя (`minAge`, `maxAge`)
6. Использует формулу Haversine для точного расчёта расстояния

## Конфигурация

Переменные окружения:

| Переменная | Обязательная | Default | Описание |
|------------|--------------|---------|----------|
| `PORT` | ❌ | 8003 | Порт HTTP сервера |
| `ENVIRONMENT` | ❌ | development | Окружение (development/production) |
| `DB_HOST` | ❌ | localhost | Хост PostgreSQL |
| `DB_PORT` | ❌ | 5432 | Порт PostgreSQL |
| `DB_USER` | ❌ | andexadmin | Пользователь БД |
| `DB_PASSWORD` | ❌ | andexevents | Пароль БД |
| `DB_NAME` | ❌ | andexevents | Имя базы данных |
| `SUPABASE_JWT_SECRET` | ✅ | — | Секрет для верификации Supabase JWT |

## Аутентификация

Сервис использует **Supabase JWT** токены для аутентификации.

### Middleware Auth

```go
// Извлекает из токена:
// - sub (supabaseUID) → c.Set("userID", sub)
// - email → c.Set("email", email)
// 
// Также ищет пользователя в БД и устанавливает:
// - dbUserID → c.Set("dbUserID", dbUserID)
```

### Формат токена

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## База данных

### Таблица User

```sql
CREATE TABLE "User" (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    "supabaseUid"           VARCHAR(255) UNIQUE NOT NULL,
    email                   VARCHAR(255) UNIQUE NOT NULL,
    "displayName"           VARCHAR(255),
    "photoUrl"              TEXT,
    bio                     TEXT,
    interests               TEXT[],
    "socialLinks"           JSONB,
    age                     INTEGER,
    gender                  VARCHAR(50),
    role                    VARCHAR(20) DEFAULT 'USER',
    "lastLatitude"          DOUBLE PRECISION,
    "lastLongitude"         DOUBLE PRECISION,
    "lastLocationUpdate"    TIMESTAMP WITH TIME ZONE,
    "isProfileVisible"      BOOLEAN DEFAULT true,
    "isLocationVisible"     BOOLEAN DEFAULT true,
    "minAge"                INTEGER,
    "maxAge"                INTEGER,
    "maxDistance"           INTEGER DEFAULT 50000,
    "fcmToken"              VARCHAR(255),
    "isOnboardingCompleted" BOOLEAN DEFAULT false,
    "createdAt"             TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt"             TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_supabase_uid ON "User"("supabaseUid");
CREATE INDEX idx_user_email ON "User"(email);
CREATE INDEX idx_user_location ON "User"("lastLatitude", "lastLongitude");
```

## Запуск

### Локальная разработка

```bash
cd services/users-service

# Установить зависимости
go mod download

# Экспортировать переменные окружения
export SUPABASE_JWT_SECRET="your-jwt-secret"
export DB_HOST="localhost"
export DB_PASSWORD="your-password"

# Запустить сервис
go run cmd/main.go
```

### Docker

```bash
# Сборка образа
docker build -t users-service .

# Запуск контейнера
docker run -p 8003:8003 \
  -e SUPABASE_JWT_SECRET="your-jwt-secret" \
  -e DB_HOST="host.docker.internal" \
  users-service
```

## Тестирование

```bash
# Все тесты
go test ./... -v

# С покрытием
go test ./internal/service/... -cover

# Только unit тесты сервиса
go test ./internal/service/... -v
```

### Покрытие тестами

| Слой | Покрытие | Описание |
|------|----------|----------|
| Service | 63%+ | Unit тесты с моками |
| Handler | — | Integration тесты (TODO) |
| Repository | — | Требует тестовую БД |

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                        HTTP Request                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Middleware Layer                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────────┐  │
│  │  Logger  │  │   CORS   │  │   Auth (Supabase JWT)    │  │
│  └──────────┘  └──────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Handler Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              UserHandler (user_handler.go)           │   │
│  │  • CreateUser    • GetCurrentUser    • UpdateProfile │   │
│  │  • UpdateLocation    • GetMatches                    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Service Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              UserService (user_service.go)           │   │
│  │  • Бизнес-логика создания пользователей             │   │
│  │  • Валидация данных                                  │   │
│  │  • Координация между репозиториями                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Repository Layer                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          UserRepository (user_repository.go)         │   │
│  │  • CRUD операции с таблицей User                     │   │
│  │  • Геопространственные запросы (Haversine)          │   │
│  │  • Динамические UPDATE запросы                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    "User" table                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Алгоритм поиска матчей

1. **Bounding Box фильтрация** — быстрая фильтрация по прямоугольной области
2. **Haversine Distance** — точный расчёт расстояния для отфильтрованных результатов

```go
// Формула Haversine
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
    const earthRadiusMeters = 6371000.0
    
    lat1Rad := lat1 * math.Pi / 180
    lat2Rad := lat2 * math.Pi / 180
    deltaLat := (lat2 - lat1) * math.Pi / 180
    deltaLon := (lon2 - lon1) * math.Pi / 180

    a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
        math.Cos(lat1Rad)*math.Cos(lat2Rad)*
        math.Sin(deltaLon/2)*math.Sin(deltaLon/2)
    c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

    return earthRadiusMeters * c
}
```

## Связанные сервисы

| Сервис | Порт | Связь |
|--------|------|-------|
| auth-service | 8001 | Общая Firebase аутентификация |
| events-service | 8002 | Пользователь создаёт события |
| friends-service | 8004 | Управление друзьями пользователя |
| match-service | 8005 | Алгоритм матчинга |

---

*Последнее обновление: Январь 2026*
