# Andex Events — API Reference

All endpoints are accessible through the Traefik API Gateway at `http://localhost/api/...`

## Auth Service (Port 8083)

### Validate Token
```
POST /api/auth/validate
Authorization: Bearer <firebase-jwt>
```
Validates the Firebase JWT and returns the associated user info.

### Get Current Auth User
```
GET /api/auth/me
Authorization: Bearer <firebase-jwt>
```
Returns the authenticated user's basic info (uid, email, internal userId).

---

## Users Service (Port 8081)

### Create User Profile
```
POST /api/users
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "displayName": "John Doe",
  "photoUrl": "https://...",
  "bio": "Hello",
  "interests": ["music", "sports"],
  "age": 25,
  "gender": "male"
}
```

### Get Current User Profile
```
GET /api/users/me
Authorization: Bearer <firebase-jwt>
```

### Update Current User Profile
```
PUT /api/users/me
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "displayName": "Updated Name",
  "bio": "Updated bio",
  "interests": ["music", "coding"]
}
```

### Complete Onboarding
```
POST /api/users/me/onboarding
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "displayName": "John",
  "interests": ["music", "sports", "travel"],
  "age": 25,
  "gender": "male"
}
```

### Update User Location
```
PUT /api/users/me/location
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "latitude": 55.7558,
  "longitude": 37.6173
}
```

### Get Nearby Matches
```
GET /api/users/matches?maxDistance=5000&limit=10
Authorization: Bearer <firebase-jwt>
```

### Submit Report
```
POST /api/users/reports
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "targetUserId": "user-123",
  "reason": "SPAM",
  "details": "Sending spam messages"
}
```

### Get User Reports
```
GET /api/users/reports
Authorization: Bearer <firebase-jwt>
```

---

## Events Service (Port 8082)

### Create Event
```
POST /api/events
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "title": "Flutter Meetup",
  "description": "Monthly Flutter developers meetup",
  "category": "TECHNOLOGY",
  "location": "Moscow, Arbat st. 15",
  "latitude": 55.7520,
  "longitude": 37.5915,
  "dateTime": "2025-07-01T18:00:00",
  "endDateTime": "2025-07-01T21:00:00",
  "price": 0,
  "isOnline": false,
  "maxParticipants": 30
}
```

### Get Events (with filters)
```
GET /api/events?latitude=55.75&longitude=37.62&maxDistance=5000&category=TECHNOLOGY&limit=20&offset=0
```

Query parameters:
- `latitude`, `longitude` — Center point for proximity search
- `maxDistance` / `radius` — Max distance in meters (default: 50000)
- `category` — Filter by category
- `limit` / `pageSize` — Results per page (default: 20)
- `offset` / `page` — Pagination offset
- `status` — Filter by status (PENDING, APPROVED, REJECTED)

### Get Event by ID
```
GET /api/events/{id}
```

### Update Event
```
PUT /api/events/{id}
Authorization: Bearer <firebase-jwt>
Content-Type: application/json
```

### Delete Event
```
DELETE /api/events/{id}
Authorization: Bearer <firebase-jwt>
```

### Participate in Event
```
POST /api/events/{id}/participate
Authorization: Bearer <firebase-jwt>
```

### Leave Event
```
DELETE /api/events/{id}/participate
Authorization: Bearer <firebase-jwt>
```

### Get Event Participants
```
GET /api/events/{id}/participants
Authorization: Bearer <firebase-jwt>
```

---

## Match Service (Go, Gin, Port 8005)

Все методы ниже требуют заголовок `Authorization: Bearer <firebase-jwt>`.

### Mutual matches и связанные списки
```
GET /api/matches
```

### История действий текущего пользователя
```
GET /api/matches/actions
```

### Входящие лайки (ещё без ответа)
```
GET /api/matches/incoming-likes
```

### Действия свайпа
```
POST /api/matches/like
POST /api/matches/dislike
POST /api/matches/super-like
Content-Type: application/json
```
Тело запроса и поля зависят от реализации handler’ов — см. `services/match-service/internal/handler/`.

---

## Upload Service (Go, Gin, Port 8006)

### Upload File
```
POST /api/upload?bucket=avatars
Authorization: Bearer <firebase-jwt>
Content-Type: multipart/form-data

file: <binary>
```

Параметр `bucket` опционален (по умолчанию часто `events`). Допустимые значения ограничены конфигурацией сервиса (`AllowedBucket`).

### Delete uploaded photo
```
DELETE /api/upload
Authorization: Bearer <firebase-jwt>
```
(параметры — см. `upload_handler.go`.)

### Публичная выдача файла
```
GET /uploads/{bucket}/{userId}/{filename}
```
Без Authorization; URL формируется из `UPLOADS_PUBLIC_BASE_URL` и пути объекта в MinIO.

Response (успех, упрощённо):
```json
{
  "success": true,
  "fileUrl": "http://localhost/uploads/events/<firebaseUid>/<filename>.jpg",
  "file": {
    "name": "<filename>.jpg",
    "size": 12345,
    "bucket": "events"
  }
}
```

---

## Standard Response Format

All Java services use a standard response wrapper:

```json
{
  "success": true,
  "data": { ... },
  "message": null
}
```

Error response:
```json
{
  "success": false,
  "data": null,
  "message": "Error description"
}
```

## Authentication

All protected endpoints require a `Authorization: Bearer <token>` header with a valid Firebase JWT. The auth-service validates the token and resolves the internal user ID.

The Flutter client obtains tokens via `IdTokenProvider`, which retries up to 10 times with 300ms delay to handle race conditions during Firebase auth state changes.
