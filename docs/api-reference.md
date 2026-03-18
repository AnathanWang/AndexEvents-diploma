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

## Match Service (Go, Port 8005)

### Get Potential Matches
```
GET /api/matches?latitude=55.75&longitude=37.62&radius=5000
Authorization: Bearer <firebase-jwt>
```

### Mark Match as Seen
```
POST /api/matches/seen
Authorization: Bearer <firebase-jwt>
Content-Type: application/json

{
  "matchUserId": "user-456"
}
```

---

## Upload Service (Go, Port 8006)

### Upload File
```
POST /api/uploads
Authorization: Bearer <firebase-jwt>
Content-Type: multipart/form-data

file: <binary>
```

Response:
```json
{
  "success": true,
  "data": {
    "fileUrl": "https://minio-host/bucket/path/file.jpg"
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
