# 📖 API Reference

Полный справочник по всем API endpoints Go микросервисов.

## 📋 Содержание

1. [Общая информация](#общая-информация)
2. [Auth Service API](#auth-service-api)
3. [Upload Service API](#upload-service-api)
4. [Events Service API](#events-service-api-planned)
5. [Коды ошибок](#коды-ошибок)

---

## 📌 Общая информация

### Base URLs

| Сервис | URL | Статус |
|--------|-----|--------|
| Auth Service | `http://localhost:8001` | ✅ Ready |
| Events Service | `http://localhost:8002` | 📋 Planned |
| Match Service | `http://localhost:8005` | ✅ Ready |
| Upload Service | `http://localhost:8006` | ✅ Ready |

### Формат ответов

Все ответы имеют единый формат:

**Успешный ответ:**
```json
{
  "success": true,
  "data": { ... }
}
```

**Ответ с ошибкой:**
```json
{
  "success": false,
  "error": "Error message"
}
```

**Ошибка валидации:**
```json
{
  "success": false,
  "error": "Validation failed",
  "details": [
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

Исключение:

- Upload Service сохраняет legacy-совместимый формат ответа: `{"success":true,"fileUrl":"...","file":{...}}` и `{"success":false,"message":"..."}`.

### Аутентификация

Защищённые эндпоинты требуют Firebase ID Token:

```http
Authorization: Bearer <firebase-id-token>
```

---

## 🔐 Auth Service API

### Health Check

Проверка работоспособности сервиса.

```http
GET /health
```

#### Response 200

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

### Create User

Создание нового пользователя после Firebase регистрации.

```http
POST /api/users
```

#### Request Body

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| `firebaseUid` | string | ✅ | UID из Firebase Auth |
| `email` | string | ✅ | Email пользователя |

```json
{
  "firebaseUid": "AbCdEf123456",
  "email": "user@example.com"
}
```

#### Response 201

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "isOnboardingCompleted": false,
    "createdAt": "2026-01-28T10:00:00Z"
  }
}
```

#### Errors

| Код | Описание |
|-----|----------|
| 400 | Невалидные данные |
| 409 | Пользователь с таким email уже существует |

---

### Get Current User

Получение профиля текущего аутентифицированного пользователя.

```http
GET /api/users/me
Authorization: Bearer <token>
```

#### Response 200

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "displayName": "John Doe",
    "bio": "Love hiking and outdoor events!",
    "age": 28,
    "avatarUrl": "https://storage.example.com/avatars/123.jpg",
    "interests": ["hiking", "music", "tech"],
    "isOnboardingCompleted": true,
    "lastLatitude": 55.7558,
    "lastLongitude": 37.6173,
    "createdAt": "2026-01-28T10:00:00Z",
    "updatedAt": "2026-01-28T12:00:00Z"
  }
}
```

#### Errors

| Код | Описание |
|-----|----------|
| 401 | Не аутентифицирован |
| 404 | Пользователь не найден |

---

### Update Current User

Обновление профиля текущего пользователя.

```http
PUT /api/users/me
Authorization: Bearer <token>
Content-Type: application/json
```

#### Request Body

| Поле | Тип | Валидация | Описание |
|------|-----|-----------|----------|
| `displayName` | string? | 2-50 символов | Отображаемое имя |
| `bio` | string? | max 500 символов | О себе |
| `age` | int? | 18-100 | Возраст |
| `avatarUrl` | string? | valid URL | URL аватара |
| `interests` | string[]? | max 10 элементов | Интересы |

```json
{
  "displayName": "John Doe Updated",
  "bio": "Updated bio text",
  "age": 29,
  "interests": ["hiking", "music"]
}
```

#### Response 200

Возвращает обновлённый профиль пользователя.

---

### Update Location

Обновление геолокации пользователя.

```http
PUT /api/users/me/location
Authorization: Bearer <token>
Content-Type: application/json
```

#### Request Body

| Поле | Тип | Валидация | Описание |
|------|-----|-----------|----------|
| `latitude` | float | -90 to 90 | Широта |
| `longitude` | float | -180 to 180 | Долгота |

```json
{
  "latitude": 55.7558,
  "longitude": 37.6173
}
```

#### Response 200

```json
{
  "success": true,
  "data": {
    "message": "Location updated"
  }
}
```

#### Errors

| Код | Описание |
|-----|----------|
| 400 | Невалидные координаты |
| 401 | Не аутентифицирован |

---

### Complete Onboarding

Завершение онбординга с заполнением профиля.

```http
POST /api/users/me/onboarding
Authorization: Bearer <token>
Content-Type: application/json
```

#### Request Body

```json
{
  "displayName": "John Doe",
  "age": 28,
  "bio": "About me...",
  "interests": ["hiking", "music", "tech"]
}
```

#### Response 200

Возвращает профиль с `isOnboardingCompleted: true`.

---

### Get Matches

Получение списка потенциальных мэтчей в радиусе.

```http
GET /api/users/matches
Authorization: Bearer <token>
```

#### Query Parameters

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `latitude` | float | из профиля | Широта для поиска |
| `longitude` | float | из профиля | Долгота для поиска |
| `radiusKm` | int | 50 | Радиус поиска в км |
| `limit` | int | 20 | Макс. количество |

#### Example

```http
GET /api/users/matches?latitude=55.7558&longitude=37.6173&radiusKm=50&limit=20
```

#### Response 200

```json
{
  "success": true,
  "data": [
    {
      "id": "user-uuid-1",
      "displayName": "Jane",
      "age": 26,
      "avatarUrl": "https://..."
    },
    {
      "id": "user-uuid-2",
      "displayName": "Bob",
      "age": 30,
      "avatarUrl": "https://..."
    }
  ]
}
```

---

### Get User by ID

Получение публичного профиля пользователя.

```http
GET /api/users/:id
```

#### Path Parameters

| Параметр | Описание |
|----------|----------|
| `id` | UUID пользователя |

#### Response 200

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "displayName": "John Doe",
    "age": 28,
    "avatarUrl": "https://...",
    "bio": "About me..."
  }
}
```

#### Errors

| Код | Описание |
|-----|----------|
| 404 | Пользователь не найден |

---

## 📤 Upload Service API

### Health Check

```http
GET /health
```

### Upload File

Legacy-совместимая загрузка файла (multipart/form-data) с полем `file`.

```http
POST /api/upload?bucket=avatars|events
Authorization: Bearer <firebase-id-token>
```

#### Response 200

```json
{
  "success": true,
  "fileUrl": "http://localhost/uploads/avatars/<userId>/<filename>",
  "file": {
    "name": "1700000000000-ab12cd34.jpg",
    "size": 12345,
    "bucket": "avatars"
  }
}
```

#### Errors

```json
{ "success": false, "message": "Unauthorized" }
```

```json
{ "success": false, "message": "No file uploaded" }
```

```json
{ "success": false, "message": "Invalid bucket name" }
```

```json
{ "success": false, "message": "Upload failed" }
```

### Public File Access

Публичная раздача файлов (аналог legacy `/public/uploads`).

```http
GET /uploads/:bucket/:userId/:filename
```

---

## 📅 Events Service API (Planned)

> 🚧 Этот сервис находится в разработке

### Planned Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | `/api/events` | Создать событие |
| GET | `/api/events` | Список событий |
| GET | `/api/events/:id` | Получить событие |
| PUT | `/api/events/:id` | Обновить событие |
| DELETE | `/api/events/:id` | Удалить событие |
| GET | `/api/events/nearby` | События рядом |
| POST | `/api/events/:id/join` | Присоединиться |
| DELETE | `/api/events/:id/leave` | Покинуть |
| GET | `/api/events/:id/participants` | Участники |

---

## ❌ Коды ошибок

### HTTP Status Codes

| Код | Название | Описание |
|-----|----------|----------|
| 200 | OK | Успешный запрос |
| 201 | Created | Ресурс создан |
| 400 | Bad Request | Невалидные данные |
| 401 | Unauthorized | Не аутентифицирован |
| 403 | Forbidden | Нет доступа |
| 404 | Not Found | Ресурс не найден |
| 409 | Conflict | Конфликт (уже существует) |
| 422 | Unprocessable Entity | Ошибка валидации |
| 429 | Too Many Requests | Превышен лимит запросов |
| 500 | Internal Server Error | Ошибка сервера |

### Примеры ошибок

**401 Unauthorized:**
```json
{
  "success": false,
  "error": "Authorization header is required"
}
```

**404 Not Found:**
```json
{
  "success": false,
  "error": "User not found"
}
```

**409 Conflict:**
```json
{
  "success": false,
  "error": "User with this email already exists"
}
```

**422 Validation Error:**
```json
{
  "success": false,
  "error": "Validation failed",
  "details": [
    {
      "field": "age",
      "message": "must be at least 18"
    },
    {
      "field": "email",
      "message": "invalid email format"
    }
  ]
}
```
