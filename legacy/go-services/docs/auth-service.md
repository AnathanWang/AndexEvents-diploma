# 🔐 Auth Service

Auth Service отвечает за аутентификацию пользователей через Firebase и управление профилями.

## 📋 Содержание

1. [Обзор](#обзор)
2. [Архитектура](#архитектура)
3. [API Endpoints](#api-endpoints)
4. [Модели данных](#модели-данных)
5. [Конфигурация](#конфигурация)
6. [Запуск](#запуск)
7. [Тестирование](#тестирование)
8. [Примеры использования](#примеры-использования)

---

## 🎯 Обзор

**Auth Service** — это микросервис для:
- Регистрации и аутентификации пользователей через Firebase
- Управления профилями пользователей
- Обновления геолокации
- Поиска потенциальных мэтчей по геолокации

### Технологии

| Компонент | Технология |
|-----------|------------|
| Язык | Go 1.21+ |
| Web Framework | [Gin](https://github.com/gin-gonic/gin) |
| База данных | PostgreSQL с PostGIS |
| Драйвер БД | [pgx/v5](https://github.com/jackc/pgx) |
| Аутентификация | Firebase Admin SDK |
| Логирование | [Zap](https://github.com/uber-go/zap) |
| Валидация | [go-playground/validator](https://github.com/go-playground/validator) |

---

## 🏗️ Архитектура

### Структура проекта

```
services/auth-service/
├── cmd/
│   └── main.go              # Точка входа приложения
├── internal/
│   ├── config/
│   │   └── config.go        # Конфигурация из env переменных
│   ├── handler/
│   │   ├── user.go          # HTTP handlers
│   │   └── user_test.go     # Тесты handlers
│   ├── middleware/
│   │   ├── auth.go          # Firebase auth middleware
│   │   └── auth_test.go     # Тесты middleware
│   ├── model/
│   │   └── user.go          # Модели данных и DTO
│   ├── repository/
│   │   └── user.go          # Слой доступа к БД
│   └── service/
│       ├── user.go          # Бизнес-логика
│       └── user_test.go     # Тесты бизнес-логики
├── go.mod
└── go.sum
```

### Слоистая архитектура

```
┌─────────────────────────────────────────┐
│              HTTP Request               │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│           Middleware (Auth)             │
│  • Проверка Firebase токена             │
│  • Извлечение firebase_uid              │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│              Handler                    │
│  • Парсинг запроса                      │
│  • Валидация входных данных             │
│  • Формирование ответа                  │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│              Service                    │
│  • Бизнес-логика                        │
│  • Обработка ошибок                     │
│  • Координация операций                 │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│            Repository                   │
│  • SQL запросы                          │
│  • Маппинг данных                       │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│            PostgreSQL                   │
└─────────────────────────────────────────┘
```

### Принципы

1. **Dependency Injection** — зависимости передаются через конструкторы
2. **Interface Segregation** — handler зависит от интерфейса, не конкретной реализации
3. **Single Responsibility** — каждый слой отвечает за свою задачу
4. **Testability** — моки позволяют тестировать слои изолированно

---

## 🌐 API Endpoints

### Базовый URL
```
http://localhost:8001
```

### Health Check

```http
GET /health
```

**Ответ:**
```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "auth-service",
    "version": "1.0.0"
  }
}
```

---

### Создание пользователя

```http
POST /api/users
Content-Type: application/json

{
  "firebaseUid": "firebase-uid-from-token",
  "email": "user@example.com"
}
```

**Ответ (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-here",
    "email": "user@example.com",
    "isOnboardingCompleted": false,
    "createdAt": "2026-01-28T10:00:00Z"
  }
}
```

**Ошибки:**
- `400` — Невалидные данные
- `409` — Пользователь уже существует

---

### Получение текущего пользователя

```http
GET /api/users/me
Authorization: Bearer <firebase-id-token>
```

**Ответ (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-here",
    "email": "user@example.com",
    "displayName": "John Doe",
    "bio": "Love hiking and events!",
    "age": 28,
    "avatarUrl": "https://...",
    "isOnboardingCompleted": true,
    "lastLatitude": 55.7558,
    "lastLongitude": 37.6173
  }
}
```

**Ошибки:**
- `401` — Не аутентифицирован
- `404` — Пользователь не найден

---

### Обновление профиля

```http
PUT /api/users/me
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "displayName": "New Name",
  "bio": "Updated bio",
  "age": 29
}
```

**Ответ (200 OK):** Обновлённый профиль пользователя

---

### Обновление геолокации

```http
PUT /api/users/me/location
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "latitude": 55.7558,
  "longitude": 37.6173
}
```

**Валидация:**
- `latitude`: от -90 до 90
- `longitude`: от -180 до 180

**Ответ (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Location updated"
  }
}
```

---

### Завершение онбординга

```http
POST /api/users/me/onboarding
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "displayName": "John Doe",
  "age": 28,
  "bio": "About me...",
  "interests": ["hiking", "music", "tech"]
}
```

**Ответ (200 OK):** Профиль с `isOnboardingCompleted: true`

---

### Получение мэтчей

```http
GET /api/users/matches?latitude=55.7558&longitude=37.6173&radiusKm=50&limit=20
Authorization: Bearer <firebase-id-token>
```

**Query параметры:**
| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| latitude | float | из профиля | Широта для поиска |
| longitude | float | из профиля | Долгота для поиска |
| radiusKm | int | 50 | Радиус поиска в км |
| limit | int | 20 | Макс. количество результатов |

**Ответ (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-1",
      "displayName": "Jane",
      "age": 26,
      "avatarUrl": "https://..."
    },
    {
      "id": "uuid-2",
      "displayName": "Bob",
      "age": 30,
      "avatarUrl": "https://..."
    }
  ]
}
```

---

### Получение пользователя по ID

```http
GET /api/users/:id
```

**Ответ (200 OK):** Публичный профиль пользователя

---

## 📦 Модели данных

### User (внутренняя модель)

```go
type User struct {
    ID                    string
    SupabaseUID           string     // Firebase UID (legacy naming)
    Email                 string
    DisplayName           *string
    Bio                   *string
    Age                   *int
    AvatarURL             *string
    Interests             []string
    LastLatitude          *float64
    LastLongitude         *float64
    IsOnboardingCompleted bool
    CreatedAt             time.Time
    UpdatedAt             time.Time
}
```

### CreateUserRequest

```go
type CreateUserRequest struct {
    FirebaseUID string `json:"firebaseUid" validate:"required"`
    Email       string `json:"email" validate:"required,email"`
}
```

### UpdateUserRequest

```go
type UpdateUserRequest struct {
    DisplayName *string  `json:"displayName" validate:"omitempty,min=2,max=50"`
    Bio         *string  `json:"bio" validate:"omitempty,max=500"`
    Age         *int     `json:"age" validate:"omitempty,min=18,max=100"`
    AvatarURL   *string  `json:"avatarUrl" validate:"omitempty,url"`
    Interests   []string `json:"interests" validate:"omitempty,max=10"`
}
```

### UpdateLocationRequest

```go
type UpdateLocationRequest struct {
    Latitude  float64 `json:"latitude" validate:"required,min=-90,max=90"`
    Longitude float64 `json:"longitude" validate:"required,min=-180,max=180"`
}
```

---

## ⚙️ Конфигурация

Сервис конфигурируется через переменные окружения:

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `PORT` | Порт сервера | `8001` |
| `DB_HOST` | Хост PostgreSQL | `localhost` |
| `DB_PORT` | Порт PostgreSQL | `5432` |
| `DB_USER` | Пользователь БД | `andexadmin` |
| `DB_PASSWORD` | Пароль БД | — |
| `DB_NAME` | Имя базы данных | `andexevents` |
| `FIREBASE_PROJECT_ID` | ID проекта Firebase | — |
| `FIREBASE_CREDENTIALS_FILE` | Путь к service account JSON | — |

### Пример .env файла

```env
PORT=8001
DB_HOST=localhost
DB_PORT=5432
DB_USER=andexadmin
DB_PASSWORD=andexevents
DB_NAME=andexevents
FIREBASE_PROJECT_ID=andexevents
FIREBASE_CREDENTIALS_FILE=./secrets/firebase-service-account.json
```

---

## 🚀 Запуск

### Предварительные требования

1. Go 1.21+
2. PostgreSQL с PostGIS
3. Firebase проект с Service Account

### Локальный запуск

```bash
cd services/auth-service

# Установка зависимостей
go mod download

# Запуск
FIREBASE_CREDENTIALS_FILE=../../secrets/firebase-service-account.json \
FIREBASE_PROJECT_ID=andexevents \
DB_HOST=localhost \
DB_PORT=5432 \
DB_USER=andexadmin \
DB_PASSWORD=andexevents \
DB_NAME=andexevents \
go run cmd/main.go
```

### Проверка работы

```bash
curl http://localhost:8001/health | jq .
```

---

## 🧪 Тестирование

### Запуск всех тестов

```bash
cd services/auth-service
go test ./... -v
```

### Запуск с покрытием

```bash
go test ./... -cover
```

### Текущее покрытие

| Пакет | Покрытие |
|-------|----------|
| handler | 48.1% |
| service | 68.4% |
| middleware | концептуальные тесты |

### Структура тестов

```
internal/
├── handler/
│   └── user_test.go      # HTTP handler тесты с моками
├── middleware/
│   └── auth_test.go      # Middleware тесты
└── service/
    └── user_test.go      # Unit тесты бизнес-логики
```

### Принципы тестирования

1. **Моки** — используем `testify/mock` для изоляции слоёв
2. **Table-driven tests** — параметризованные тесты где уместно
3. **AAA pattern** — Arrange, Act, Assert в каждом тесте

---

## 💡 Примеры использования

### Регистрация нового пользователя (Flutter)

```dart
// 1. Регистрация в Firebase
final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// 2. Получение токена
final token = await credential.user!.getIdToken();

// 3. Создание пользователя в нашей БД
final response = await http.post(
  Uri.parse('$baseUrl/api/users'),
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'firebaseUid': credential.user!.uid,
    'email': email,
  }),
);
```

### Получение профиля (Flutter)

```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();

final response = await http.get(
  Uri.parse('$baseUrl/api/users/me'),
  headers: {
    'Authorization': 'Bearer $token',
  },
);

final user = jsonDecode(response.body)['data'];
```

### Обновление локации (Flutter)

```dart
final position = await Geolocator.getCurrentPosition();
final token = await FirebaseAuth.instance.currentUser!.getIdToken();

await http.put(
  Uri.parse('$baseUrl/api/users/me/location'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'latitude': position.latitude,
    'longitude': position.longitude,
  }),
);
```

---

## 🔒 Безопасность

1. **Firebase Auth** — все защищённые эндпоинты требуют валидный Firebase ID token
2. **Token Verification** — токены проверяются через Firebase Admin SDK
3. **Input Validation** — все входные данные валидируются через go-playground/validator
4. **SQL Injection Prevention** — используются параметризованные запросы через pgx

---

## 📈 Мониторинг

### Логирование

Сервис использует структурированное логирование через Zap:

```
2026-01-28T10:00:00.000+0300  INFO  cmd/main.go:45  Starting auth-service  {"port": 8001}
2026-01-28T10:00:01.000+0300  INFO  service/user.go:37  User created  {"userID": "uuid-here"}
```

### Health Check

Эндпоинт `/health` можно использовать для:
- Kubernetes liveness/readiness probes
- Load balancer health checks
- Мониторинга uptime

---

## 🛠️ Troubleshooting

### Ошибка подключения к БД

```
Failed to connect to database
```

**Решение:** Проверьте что PostgreSQL запущен и credentials корректны.

### Firebase token verification failed

```
Invalid Firebase token
```

**Решение:** 
1. Проверьте `FIREBASE_PROJECT_ID`
2. Проверьте путь к `firebase-service-account.json`
3. Убедитесь что токен не истёк

### User not found after registration

**Решение:** Убедитесь что `POST /api/users` вызывается после Firebase регистрации.

---

## 📝 Changelog

### v1.0.0 (2026-01-28)
- ✅ Базовая аутентификация через Firebase
- ✅ CRUD операции для пользователей
- ✅ Геолокация и поиск мэтчей
- ✅ Онбординг
- ✅ Unit тесты
