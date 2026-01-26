# Andex Events - Архитектурные диаграммы

## Содержание

1. [Общая архитектура системы](#общая-архитектура-системы)
2. [Архитектура базы данных](#архитектура-базы-данных)
3. [Потоки данных](#потоки-данных)
4. [Диаграммы последовательности](#диаграммы-последовательности)

---

## Общая архитектура системы

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Flutter Mobile Application                    │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Presentation│  │  BLoC State  │  │   Services   │  │   │
│  │  │   Layer     │──│  Management  │──│    Layer     │  │   │
│  │  └─────────────┘  └──────────────┘  └──────────────┘  │   │
│  │         │                 │                 │           │   │
│  │         └─────────────────┴─────────────────┘           │   │
│  │                           │                              │   │
│  └───────────────────────────┼──────────────────────────────┘   │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               │ HTTP/REST API
                               │ WebSocket (future)
                               │
┌──────────────────────────────┼───────────────────────────────────┐
│                         API GATEWAY                               │
└──────────────────────────────┬───────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Auth Service │    │  API Service  │    │Upload Service │
│   (Supabase)  │    │   (Express)   │    │   (Multer)    │
└───────┬───────┘    └───────┬───────┘    └───────┬───────┘
        │                    │                    │
        │                    ▼                    │
        │            ┌───────────────┐            │
        │            │  PostgreSQL   │            │
        │            │   + PostGIS   │            │
        │            └───────────────┘            │
        │                                         │
        ▼                                         ▼
┌───────────────┐                        ┌───────────────┐
│   Supabase    │                        │  Local File   │
│    Storage    │                        │    System     │
│ (avatars,     │                        │   /uploads/   │
│   events)     │                        └───────────────┘
└───────────────┘
```

### Technology Stack Overview

```
┌────────────────────────────────────────────────────────────────┐
│                         FRONTEND                                │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Flutter 3.9.2+ / Dart 3.9.2+                                  │
│  ├── State Management: flutter_bloc ^8.1.6                     │
│  ├── Navigation: Material 3 Navigator                          │
│  ├── DI: Provider pattern (manual)                             │
│  ├── HTTP Client: dio ^5.7.0                                   │
│  ├── Local Storage: shared_preferences, flutter_secure_storage│
│  ├── Auth: supabase_flutter ^2.6.0                            │
│  ├── Maps: yandex_mapkit ^4.1.0                               │
│  └── Image Processing: flutter_image_compress ^2.3.0          │
│                                                                  │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                          BACKEND                                │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Node.js + TypeScript 5.9.3                                    │
│  ├── Framework: express ^5.1.0                                 │
│  ├── ORM: prisma ^6.19.0                                       │
│  ├── Auth: jsonwebtoken ^9.0.2                                 │
│  ├── File Upload: multer ^1.4.5                                │
│  ├── Image Processing: sharp ^0.33.5                           │
│  ├── Validation: zod ^4.1.12                                   │
│  ├── Logging: winston ^3.15.0                                  │
│  └── Security: helmet ^8.1.0, express-rate-limit ^7.5.1       │
│                                                                  │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                        DATABASE                                 │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PostgreSQL 14+                                                │
│  └── Extensions: PostGIS (geography, geometry)                 │
│                                                                  │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES                            │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ├── Supabase (Auth + Storage)                                │
│  ├── Yandex Maps API (MapKit + Geocoding)                     │
│  └── Firebase Cloud Messaging (FCM) - planned                  │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

---

## Архитектура базы данных

### Entity Relationship Diagram (ERD)

```
┌─────────────────────────────────────────────────────────────────────┐
│                           DATABASE SCHEMA                            │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐
│         User             │
├──────────────────────────┤
│ PK id (uuid)             │
│ UK supabaseUid           │◄─────────────────┐
│ UK email                 │                  │
│    displayName           │                  │
│    photoUrl              │                  │
│    bio                   │                  │
│    interests[]           │                  │
│    socialLinks (json)    │                  │
│    age                   │                  │
│    gender                │                  │
│    role (enum)           │                  │
│    lastLatitude          │                  │
│    lastLongitude         │                  │
│    lastLocationUpdate    │                  │
│    isProfileVisible      │                  │
│    isLocationVisible     │                  │
│    minAge                │                  │
│    maxAge                │                  │
│    maxDistance           │                  │
│    fcmToken              │                  │
│    isOnboardingCompleted │                  │
│    createdAt             │                  │
│    updatedAt             │                  │
└──────────┬───────────────┘                  │
           │                                  │
           │ 1:N (creator)                    │
           │                                  │
           ▼                                  │
┌──────────────────────────┐                  │
│        Event             │                  │
├──────────────────────────┤                  │
│ PK id (uuid)             │                  │
│    title                 │                  │
│    description           │                  │
│    category              │                  │
│    location              │                  │
│    latitude              │                  │
│    longitude             │                  │
│    locationGeo (postgis) │◄─────────────────┼── ST_DWithin queries
│    dateTime              │                  │
│    endDateTime           │                  │
│    price                 │                  │
│    imageUrl              │                  │
│    isOnline              │                  │
│    status (enum)         │                  │
│    rejectionReason       │                  │
│    maxParticipants       │                  │
│    minAge                │                  │
│    maxAge                │                  │
│ FK createdById           │──────────────────┘
│    createdAt             │
│    updatedAt             │
└──────────┬───────────────┘
           │
           │ 1:N
           │
           ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│     Participant          │   N:1   │         User             │
├──────────────────────────┤◄────────┤ (referenced above)       │
│ PK id (uuid)             │         └──────────────────────────┘
│ FK userId                │
│ FK eventId               │
│    status (enum)         │    Status: INTERESTED | GOING
│    joinedAt              │
│    updatedAt             │
│ UK (userId, eventId)     │
└──────────────────────────┘


┌──────────────────────────┐         ┌──────────────────────────┐
│        Match             │   N:1   │         User             │
├──────────────────────────┤◄────────┤  (userA)                 │
│ PK id (uuid)             │         └──────────────────────────┘
│ FK userAId               │
│ FK userBId               │         ┌──────────────────────────┐
│    userAAction (enum)    │   N:1   │         User             │
│    userBAction (enum)    │◄────────┤  (userB)                 │
│    isMutual              │         └──────────────────────────┘
│    matchedAt             │
│    createdAt             │    Actions: LIKE | DISLIKE | SUPER_LIKE
│    updatedAt             │
│ UK (userAId, userBId)    │
└──────────────────────────┘


┌──────────────────────────┐         ┌──────────────────────────┐
│     Notification         │   N:1   │         User             │
├──────────────────────────┤◄────────┤  (sender)                │
│ PK id (uuid)             │         └──────────────────────────┘
│    type                  │
│    title                 │         ┌──────────────────────────┐
│    body                  │   N:1   │         User             │
│    data (json)           │◄────────┤  (receiver)              │
│ FK senderId              │         └──────────────────────────┘
│ FK receiverId            │
│    isRead                │    Types: MATCH, EVENT_REMINDER, 
│    createdAt             │           EVENT_APPROVED, etc.
└──────────────────────────┘
```

### Database Indexes

```
┌─────────────────────────────────────────────────────────────────┐
│                       INDEX STRATEGY                             │
└─────────────────────────────────────────────────────────────────┘

User Table:
├── PRIMARY KEY: id (uuid)
├── UNIQUE INDEX: supabaseUid
├── UNIQUE INDEX: email
├── INDEX: (lastLatitude, lastLongitude)  ← for geospatial queries
└── INDEX: isOnboardingCompleted

Event Table:
├── PRIMARY KEY: id (uuid)
├── INDEX: createdById
├── INDEX: status
├── INDEX: dateTime
├── INDEX: category
├── INDEX: (status, dateTime)  ← composite for event listing
├── INDEX: (category, status)  ← composite for filtering
└── GIST INDEX: locationGeo    ← PostGIS spatial index

Participant Table:
├── PRIMARY KEY: id (uuid)
├── INDEX: userId
├── INDEX: eventId
└── UNIQUE INDEX: (userId, eventId)

Match Table:
├── PRIMARY KEY: id (uuid)
├── INDEX: userAId
├── INDEX: userBId
├── INDEX: isMutual
└── UNIQUE INDEX: (userAId, userBId)

Notification Table:
├── PRIMARY KEY: id (uuid)
├── INDEX: receiverId
├── INDEX: isRead
├── INDEX: type
└── INDEX: (receiverId, isRead)  ← composite for filtering
```

### Data Types and Constraints

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENUMS & CONSTRAINTS                           │
└─────────────────────────────────────────────────────────────────┘

enum UserRole {
  USER        ← Default role
  MODERATOR   ← Can approve/reject events
  ADMIN       ← Full access
}

enum EventStatus {
  PENDING     ← Default, awaiting moderation
  APPROVED    ← Visible to users
  REJECTED    ← Hidden with rejection reason
}

enum MatchAction {
  LIKE        ← Swipe right
  DISLIKE     ← Swipe left
  SUPER_LIKE  ← Special like
}

enum ParticipantStatus {
  INTERESTED  ← User is interested
  GOING       ← User confirmed attendance
}

Constraints:
├── User.lastLatitude:  -90.0 to 90.0
├── User.lastLongitude: -180.0 to 180.0
├── User.maxDistance:   100 to 100000 (meters)
├── User.age:           18 to 100
├── Event.latitude:     -90.0 to 90.0
├── Event.longitude:    -180.0 to 180.0
├── Event.price:        >= 0
└── Event.dateTime:     >= NOW()
```

---

## Потоки данных

### Authentication Flow

```
┌──────────┐                                                    ┌──────────┐
│  Client  │                                                    │ Backend  │
└────┬─────┘                                                    └────┬─────┘
     │                                                               │
     │  1. Sign Up / Sign In                                        │
     │  POST /auth/signup                                           │
     ├──────────────────────────────────────────────────────────────►
     │  { email, password, displayName }                            │
     │                                                               │
     │                                                               │
     │                    ┌──────────────┐                          │
     │                    │   Supabase   │                          │
     │                    │     Auth     │                          │
     │                    └──────┬───────┘                          │
     │                           │                                  │
     │  2. Create Auth User      │                                  │
     │◄──────────────────────────┤                                  │
     │  { user, session }        │                                  │
     │                           │                                  │
     │  3. Create DB User                                           │
     │  POST /api/users          │                                  │
     ├───────────────────────────┼─────────────────────────────────►
     │  { supabaseUid, email, displayName }                         │
     │                           │                                  │
     │                           │  4. Insert into DB               │
     │                           │  INSERT INTO User                │
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │◄─────────────────┤          │   │
     │                           │  { id, ... }     └──────────┘   │
     │                           │                                  │
     │  5. Return User + Token                                      │
     │◄─────────────────────────┼──────────────────────────────────┤
     │  { user, accessToken }   │                                  │
     │                           │                                  │
     │  6. Store Token                                              │
     │  (Secure Storage)         │                                  │
     │                           │                                  │
     │                           │                                  │
     │  All subsequent requests  │                                  │
     │  Authorization: Bearer <token>                               │
     ├──────────────────────────────────────────────────────────────►
     │                                                               │
```

### Event Creation Flow

```
┌──────────┐                                                    ┌──────────┐
│  Client  │                                                    │ Backend  │
└────┬─────┘                                                    └────┬─────┘
     │                                                               │
     │  1. Pick Image                                               │
     │  (ImagePicker)                                               │
     │                                                               │
     │  2. Compress Image                                           │
     │  (ImageUtils.compressImage)                                  │
     │                                                               │
     │  3. Upload Image                                             │
     │  POST /api/upload?bucket=events                              │
     ├──────────────────────────────────────────────────────────────►
     │  FormData: { file: compressed.jpg }                          │
     │  Authorization: Bearer <token>                               │
     │                                                               │
     │                    ┌──────────────┐                          │
     │                    │   Supabase   │                          │
     │                    │   Storage    │                          │
     │                    └──────┬───────┘                          │
     │                           │                                  │
     │  4. Upload to Storage     │                                  │
     │                           ├─────────────────►                │
     │                           │  uploadBinary()                  │
     │                           │                                  │
     │  5. Return Public URL                                        │
     │◄──────────────────────────┼──────────────────────────────────┤
     │  { fileUrl: "https://..." }                                  │
     │                           │                                  │
     │  6. Geocode Address                                          │
     │  (YandexGeocoder)         │                                  │
     │  "Москва, Красная площадь" → (55.7539, 37.6208)            │
     │                           │                                  │
     │  7. Create Event                                             │
     │  POST /api/events         │                                  │
     ├──────────────────────────────────────────────────────────────►
     │  {                        │                                  │
     │    title, description,    │                                  │
     │    category, location,    │                                  │
     │    latitude, longitude,   │  8. Insert with PostGIS          │
     │    dateTime, price,       │  INSERT INTO Event               │
     │    imageUrl               │  (..., ST_MakePoint(lon, lat))   │
     │  }                        ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │◄─────────────────┤ +PostGIS │   │
     │  9. Return Created Event  │  { id, ... }     └──────────┘   │
     │◄──────────────────────────┼──────────────────────────────────┤
     │  {                        │                                  │
     │    id, title, ...,        │                                  │
     │    status: "PENDING"      │                                  │
     │  }                        │                                  │
     │                           │                                  │
     │  10. Navigate to event detail                                │
     │                           │                                  │
```

### Event Discovery Flow (Geospatial)

```
┌──────────┐                                                    ┌──────────┐
│  Client  │                                                    │ Backend  │
└────┬─────┘                                                    └────┬─────┘
     │                                                               │
     │  1. Get Current Location                                     │
     │  (Geolocator.getCurrentPosition)                             │
     │  → (55.7558, 37.6173)                                        │
     │                                                               │
     │  2. Update User Location                                     │
     │  PUT /api/users/me/location                                  │
     ├──────────────────────────────────────────────────────────────►
     │  { latitude: 55.7558, longitude: 37.6173 }                   │
     │                           │                                  │
     │                           │  UPDATE User                     │
     │                           │  SET lastLatitude = ...          │
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │◄─────────────────┤          │   │
     │  3. Success               │                  └──────────┘   │
     │◄──────────────────────────┼──────────────────────────────────┤
     │                           │                                  │
     │  4. Fetch Nearby Events                                      │
     │  GET /api/events/nearby?lat=55.7558&lon=37.6173&radius=5000 │
     ├──────────────────────────────────────────────────────────────►
     │                           │                                  │
     │                           │  5. PostGIS Query                │
     │                           │  SELECT * FROM Event             │
     │                           │  WHERE ST_DWithin(               │
     │                           │    locationGeo,                  │
     │                           │    ST_MakePoint(37.6173, 55.7558),│
     │                           │    5000                          │
     │                           │  )                               │
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │                  │ +PostGIS │   │
     │                           │◄─────────────────┤          │   │
     │  6. Return Events         │  [events with    └──────────┘   │
     │◄──────────────────────────┼──────────────────────────────────┤
     │  {                        │   distance field]                │
     │    events: [              │                                  │
     │      { id, title, ..., distance: 1234 },                     │
     │      { id, title, ..., distance: 2567 },                     │
     │      ...                  │                                  │
     │    ],                     │                                  │
     │    pagination: {...}      │                                  │
     │  }                        │                                  │
     │                           │                                  │
     │  7. Display on Map                                           │
     │  (Yandex MapKit)          │                                  │
     │  - Place markers at event locations                          │
     │  - Cluster nearby events  │                                  │
     │                           │                                  │
```

### Match Flow (Tinder-style)

```
┌──────────┐                                                    ┌──────────┐
│  User A  │                                                    │ Backend  │
└────┬─────┘                                                    └────┬─────┘
     │                                                               │
     │  1. Get Potential Matches                                    │
     │  GET /api/users/matches?lat=55.7558&lon=37.6173&radius=50   │
     ├──────────────────────────────────────────────────────────────►
     │                           │                                  │
     │                           │  2. Find Users                   │
     │                           │  SELECT * FROM User              │
     │                           │  WHERE                           │
     │                           │    id != userA_id AND            │
     │                           │    isOnboardingCompleted = true  │
     │                           │    AND isProfileVisible = true   │
     │                           │    AND lat BETWEEN ... AND ...   │
     │                           │    AND lon BETWEEN ... AND ...   │
     │                           │    AND age BETWEEN minAge, maxAge│
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │  3. Return Match          │◄─────────────────┤          │   │
     │  Candidates               │  [users]         └──────────┘   │
     │◄──────────────────────────┼──────────────────────────────────┤
     │  {                        │                                  │
     │    data: [user1, user2, ...]                                 │
     │  }                        │                                  │
     │                           │                                  │
     │  4. Swipe Right (LIKE)                                       │
     │  POST /api/matches        │                                  │
     ├──────────────────────────────────────────────────────────────►
     │  {                        │                                  │
     │    targetUserId: userB_id,│                                  │
     │    action: "LIKE"         │  5. Upsert Match                 │
     │  }                        │  INSERT INTO Match               │
     │                           │  (userAId, userBId, userAAction) │
     │                           │  VALUES (userA, userB, 'LIKE')   │
     │                           │  ON CONFLICT UPDATE              │
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │                                  │
     │                           │  6. Check if mutual              │
     │                           │  SELECT * FROM Match             │
     │                           │  WHERE userAId = userB AND       │
     │                           │        userBId = userA           │
     │                           │◄─────────────────┤          │   │
     │                           │  userBAction = 'LIKE'            │
     │                           │                  └──────────┘   │
     │                           │                                  │
     │                           │  7. If mutual → Update           │
     │                           │  UPDATE Match                    │
     │                           │  SET isMutual = true,            │
     │                           │      matchedAt = NOW()           │
     │                           ├─────────────────►┌──────────┐   │
     │                           │                  │PostgreSQL│   │
     │                           │                                  │
     │                           │  8. Create Notification          │
     │                           │  INSERT INTO Notification        │
     │                           │  (type = 'MATCH', ...)           │
     │                           │◄─────────────────┤          │   │
     │  9. Return Match Result   │                  └──────────┘   │
     │◄──────────────────────────┼──────────────────────────────────┤
     │  {                        │                                  │
     │    success: true,         │                                  │
     │    isMutual: true,        │                                  │
     │    matchedAt: "..."       │                                  │
     │  }                        │                                  │
     │                           │                                  │
     │  10. Show "It's a Match!" modal                              │
     │                           │                                  │
     │                           │  11. Push Notification to User B │
     │                           │  (FCM - future)                  │
     │                           │                                  │
```

---

## Диаграммы последовательности

### User Registration Sequence

```
┌──────┐   ┌─────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│Client│   │AuthBloc │   │  Auth    │   │ Backend │   │PostgreSQL│
│      │   │         │   │ Service  │   │   API   │   │          │
└───┬──┘   └────┬────┘   └────┬─────┘   └────┬────┘   └────┬─────┘
    │           │             │              │              │
    │ tap Sign Up             │              │              │
    ├──────────►│             │              │              │
    │           │             │              │              │
    │           │ SignUpRequested            │              │
    │           │ event       │              │              │
    │           ├────────────►│              │              │
    │           │             │              │              │
    │           │             │ signUpWithEmail()           │
    │           │             ├─────────────►│              │
    │           │             │              │              │
    │           │             │         ┌────▼─────┐        │
    │           │             │         │ Supabase │        │
    │           │             │         │   Auth   │        │
    │           │             │         └────┬─────┘        │
    │           │             │              │              │
    │           │             │◄─────────────┤              │
    │           │             │ { user, session }           │
    │           │             │              │              │
    │           │             │ createUserInBackend()       │
    │           │             ├─────────────►│              │
    │           │             │              │              │
    │           │             │              │ INSERT User  │
    │           │             │              ├─────────────►│
    │           │             │              │              │
    │           │             │              │◄─────────────┤
    │           │             │              │ { id, ... }  │
    │           │             │              │              │
    │           │             │              │ mkdir uploads/│
    │           │             │              │  avatars/userId│
    │           │             │              │  events/userId │
    │           │             │              │              │
    │           │             │◄─────────────┤              │
    │           │             │ { success }  │              │
    │           │             │              │              │
    │           │◄────────────┤              │              │
    │           │ AuthResponse│              │              │
    │           │             │              │              │
    │           │ emit(       │              │              │
    │           │  Authenticated)            │              │
    │           │             │              │              │
    │◄──────────┤             │              │              │
    │ Navigate  │             │              │              │
    │ to Home   │             │              │              │
    │           │             │              │              │
```

### Event Participation Sequence

```
┌──────┐   ┌──────────┐   ┌─────────┐   ┌─────────┐   ┌──────────┐
│Client│   │EventBloc │   │ Event   │   │ Backend │   │PostgreSQL│
│      │   │          │   │ Service │   │   API   │   │          │
└───┬──┘   └────┬─────┘   └────┬────┘   └────┬────┘   └────┬─────┘
    │           │              │             │              │
    │ tap "I'm Going"          │             │              │
    ├──────────►│              │             │              │
    │           │              │             │              │
    │           │ JoinEventRequested         │              │
    │           ├─────────────►│             │              │
    │           │              │             │              │
    │           │              │ participateInEvent()       │
    │           │              ├────────────►│              │
    │           │              │             │              │
    │           │              │      POST /api/events/:id/participate
    │           │              │             │              │
    │           │              │             │ authMiddleware
    │           │              │             │ verify JWT   │
    │           │              │             │              │
    │           │              │             │ UPSERT Participant
    │           │              │             ├─────────────►│
    │           │              │             │              │
    │           │              │             │ INSERT INTO  │
    │           │              │             │ Participant  │
    │           │              │             │ (userId,     │
    │           │              │             │  eventId,    │
    │           │              │             │  status)     │
    │           │              │             │ VALUES       │
    │           │              │             │ (..., 'GOING')
    │           │              │             │ ON CONFLICT  │
    │           │              │             │ UPDATE status│
    │           │              │             │              │
    │           │              │             │◄─────────────┤
    │           │              │             │ { participant }
    │           │              │             │              │
    │           │              │             │ SELECT Event │
    │           │              │             │ WITH participants
    │           │              │             ├─────────────►│
    │           │              │             │              │
    │           │              │             │◄─────────────┤
    │           │              │◄────────────┤ { event }    │
    │           │              │ { event }   │              │
    │           │◄─────────────┤             │              │
    │           │              │             │              │
    │           │ emit(        │             │              │
    │           │  EventJoined)│             │              │
    │           │              │             │              │
    │◄──────────┤              │             │              │
    │ Update UI │              │             │              │
    │ "Going" ✓ │              │             │              │
    │           │              │             │              │
```

### Image Upload Security Flow

```
┌──────┐   ┌────────┐   ┌─────────┐   ┌──────────┐   ┌─────────┐
│Client│   │ Upload │   │  Auth   │   │  File    │   │Supabase │
│      │   │Service │   │Middleware   │ Storage  │   │ Storage │
└───┬──┘   └───┬────┘   └────┬────┘   └────┬─────┘   └────┬────┘
    │          │             │             │              │
    │ selectImage()          │             │              │
    ├─────────►│             │             │              │
    │          │             │             │              │
    │          │ compressImage()           │              │
    │          │ 70% quality │             │              │
    │          │ min 512x512 │             │              │
    │          │             │             │              │
    │◄─────────┤             │             │              │
    │ compressed.jpg         │             │              │
    │          │             │             │              │
    │ uploadProfilePhoto()   │             │              │
    ├─────────►│             │             │              │
    │          │             │             │              │
    │          │ POST /api/upload?bucket=avatars          │
    │          ├────────────►│             │              │
    │          │ Bearer token│             │              │
    │          │             │             │              │
    │          │             │ verify JWT  │              │
    │          │             │ extract userId             │
    │          │             │             │              │
    │          │             ├────────────►│              │
    │          │             │ multer      │              │
    │          │             │ middleware  │              │
    │          │             │             │              │
    │          │             │             │ validate:    │
    │          │             │             │ - MIME type  │
    │          │             │             │ - extension  │
    │          │             │             │ - file size  │
    │          │             │             │ - magic bytes│
    │          │             │             │              │
    │          │             │             │ sanitize:    │
    │          │             │             │ - filename   │
    │          │             │             │ - path       │
    │          │             │             │              │
    │          │             │             │ save to:     │
    │          │             │             │ uploads/     │
    │          │             │             │  avatars/    │
    │          │             │             │   {userId}/  │
    │          │             │             │    {timestamp}.jpg
    │          │             │             │              │
    │          │             │             ├─────────────►│
    │          │             │             │ uploadBinary()
    │          │             │             │              │
    │          │             │             │◄─────────────┤
    │          │             │             │ public URL   │
    │          │             │             │              │
    │          │             │◄────────────┤              │
    │          │             │ { fileUrl } │              │
    │          │◄────────────┤             │              │
    │◄─────────┤             │             │              │
    │ imageUrl │             │             │              │
    │          │             │             │              │
    │ updateProfile(photoUrl)│             │              │
    ├─────────►│             │             │              │
    │          │             │             │              │
    │          │ PUT /api/users/me         │              │
    │          ├────────────►│             │              │
    │          │             │             │              │
    │          │             │ UPDATE User │              │
    │          │             │ SET photoUrl│              │
    │          │             │             │              │
    │◄─────────┤             │             │              │
    │ success  │             │             │              │
    │          │             │             │              │
```

### PostGIS Geospatial Query Flow

```
┌──────────┐           ┌──────────┐           ┌──────────────┐
│  Client  │           │ Backend  │           │  PostgreSQL  │
│          │           │   API    │           │   +PostGIS   │
└────┬─────┘           └────┬─────┘           └──────┬───────┘
     │                      │                        │
     │ GET /api/events/nearby                        │
     │   ?lat=55.7558&lon=37.6173&radius=5000        │
     ├─────────────────────►│                        │
     │                      │                        │
     │                      │ Validate coordinates   │
     │                      │ lat: -90 to 90        │
     │                      │ lon: -180 to 180      │
     │                      │                        │
     │                      │ Build PostGIS Query:   │
     │                      │                        │
     │                      │ SELECT                 │
     │                      │   e.*,                 │
     │                      │   ST_Distance(         │
     │                      │     e.locationGeo,     │
     │                      │     ST_SetSRID(        │
     │                      │       ST_MakePoint(    │
     │                      │         37.6173,       │ ← lon first!
     │                      │         55.7558        │ ← lat second!
     │                      │       ),               │
     │                      │       4326             │ ← SRID (WGS84)
     │                      │     )::geography       │
     │                      │   ) as distance        │
     │                      │ FROM Event e           │
     │                      │ WHERE                  │
     │                      │   e.status = 'APPROVED'│
     │                      │   AND ST_DWithin(      │
     │                      │     e.locationGeo,     │
     │                      │     ST_SetSRID(        │
     │                      │       ST_MakePoint(    │
     │                      │         37.6173,       │
     │                      │         55.7558),      │
     │                      │       4326             │
     │                      │     )::geography,      │
     │                      │     5000               │ ← radius in meters
     │                      │   )                    │
     │                      │ ORDER BY distance      │
     │                      │ LIMIT 20               │
     │                      │                        │
     │                      ├───────────────────────►│
     │                      │                        │
     │                      │                  ┌─────▼──────┐
     │                      │                  │ PostGIS    │
     │                      │                  │ Engine     │
     │                      │                  │            │
     │                      │                  │ 1. Use GIST│
     │                      │                  │    index on│
     │                      │                  │    locationGeo
     │                      │                  │            │
     │                      │                  │ 2. Filter  │
     │                      │                  │    by radius│
     │                      │                  │    (5km)   │
     │                      │                  │            │
     │                      │                  │ 3. Calculate│
     │                      │                  │    distance│
     │                      │                  │    (meters)│
     │                      │                  │            │
     │                      │                  │ 4. Sort by │
     │                      │                  │    distance│
     │                      │                  └─────┬──────┘
     │                      │                        │
     │                      │◄───────────────────────┤
     │                      │ [                      │
     │                      │   {                    │
     │                      │     id: "...",         │
     │                      │     title: "Concert",  │
     │                      │     latitude: 55.7560, │
     │                      │     longitude: 37.6180,│
     │                      │     distance: 123.45   │
     │                      │   },                   │
     │                      │   { ... }              │
     │                      │ ]                      │
     │                      │                        │
     │◄─────────────────────┤                        │
     │ { events: [...] }    │                        │
     │                      │                        │
     │ Display on Map       │                        │
     │ (Yandex MapKit)      │                        │
     │ - Sort by distance   │                        │
     │ - Show nearest first │                        │
     │                      │                        │
```

---

## Security Architecture

### Multi-Layer Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     SECURITY LAYERS                              │
└─────────────────────────────────────────────────────────────────┘

Layer 1: Network Security
├── HTTPS Only (TLS 1.3)
├── CORS Configuration
├── Rate Limiting (express-rate-limit)
│   ├── Auth: 5 requests / 15 min
│   ├── Upload: 10 requests / 1 min
│   └── General: 100 requests / 15 min
└── DDoS Protection (Cloudflare - recommended)

Layer 2: Authentication & Authorization
├── Supabase Auth (OAuth 2.0)
│   ├── JWT tokens (RS256)
│   ├── Refresh tokens
│   └── Session management
├── Backend JWT Verification
│   ├── SUPABASE_JWT_SECRET validation
│   └── Token expiration check
└── Role-Based Access Control (RBAC)
    ├── USER (default)
    ├── MODERATOR (approve events)
    └── ADMIN (full access)

Layer 3: Input Validation
├── Zod Schema Validation
│   ├── Type checking
│   ├── Length constraints
│   └── Format validation
├── Prisma Type Safety
└── Sanitization
    ├── SQL Injection prevention (Prisma)
    ├── XSS prevention (Flutter auto-escape)
    └── Path Traversal prevention

Layer 4: File Upload Security
├── MIME Type Validation
├── File Extension Whitelist
├── Magic Bytes Verification
├── File Size Limits
│   ├── Avatars: 5MB
│   └── Events: 10MB
├── Filename Sanitization
│   ├── Remove '..'
│   ├── Remove '/', '\'
│   └── Alphanumeric only
└── Access Control
    ├── Users can only access own files
    └── Public read, authenticated write

Layer 5: Database Security
├── Parameterized Queries (Prisma)
├── Row-Level Security (planned)
├── Encryption at Rest
└── Regular Backups

Layer 6: API Security
├── Helmet.js Headers
│   ├── X-Frame-Options: DENY
│   ├── X-Content-Type-Options: nosniff
│   ├── Strict-Transport-Security
│   └── Content-Security-Policy
├── Request Logging (Winston)
└── Error Handling (no stack traces in prod)
```

### Authentication Flow Security

```
┌─────────────────────────────────────────────────────────────────┐
│                   JWT TOKEN FLOW                                 │
└─────────────────────────────────────────────────────────────────┘

1. User authenticates with Supabase
   ↓
2. Supabase returns JWT (signed with SUPABASE_JWT_SECRET)
   ↓
   Token Structure:
   {
     "sub": "uuid-of-user",           ← supabaseUid
     "email": "user@example.com",
     "role": "authenticated",
     "iat": 1234567890,               ← issued at
     "exp": 1234571490                ← expires in 1 hour
   }
   ↓
3. Client stores token securely
   - iOS: Keychain
   - Android: EncryptedSharedPreferences
   ↓
4. Client sends token in every request
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ↓
5. Backend verifies token
   - Signature validation
   - Expiration check
   - Extract user info
   ↓
6. Backend fetches user from DB
   - Find by supabaseUid (from JWT "sub")
   - Get internal userId (UUID)
   ↓
7. Attach user to request
   req.user = {
     uid: "supabase-uid",
     userId: "internal-uuid",
     email: "user@example.com"
   }
   ↓
8. Controller uses req.user.userId for all operations
```

---

## State Management Architecture (BLoC)

```
┌─────────────────────────────────────────────────────────────────┐
│                  BLoC PATTERN ARCHITECTURE                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │   Screen   │  │   Screen   │  │   Screen   │               │
│  │  Widget    │  │  Widget    │  │  Widget    │               │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘               │
│         │                │                │                      │
│         └────────────────┴────────────────┘                      │
│                          │                                       │
│                ┌─────────▼──────────┐                           │
│                │   BlocBuilder /    │                           │
│                │   BlocListener     │                           │
│                └─────────┬──────────┘                           │
│                          │                                       │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           │ UI Events
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                         BLoC Layer                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                       EventBloc                           │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │ Events:                                             │ │  │
│  │  │  - LoadEvents                                       │ │  │
│  │  │  - CreateEvent                                      │ │  │
│  │  │  - JoinEvent                                        │ │  │
│  │  │  - LeaveEvent                                       │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  │                         │                                 │  │
│  │                         ▼                                 │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │ States:                                             │ │  │
│  │  │  - EventInitial                                     │ │  │
│  │  │  - EventLoading                                     │ │  │
│  │  │  - EventLoaded(events: List<Event>)               │ │  │
│  │  │  - EventError(message: String)                     │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                       │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           │ Service Calls
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Service Layer                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    EventService                           │  │
│  │  - getAllEvents()                                         │  │
│  │  - getNearbyEvents(lat, lon, radius)                    │  │
│  │  - createEvent(event)                                     │  │
│  │  - joinEvent(eventId)                                     │  │
│  │  - leaveEvent(eventId)                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                       │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           │ HTTP Requests
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        HTTP Layer (Dio)                          │
│  - Base URL configuration                                        │
│  - Interceptors (Auth, Logging, Error handling)                 │
│  - Timeout configuration                                         │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
                    Backend API
```

### BLoC Event Flow Example

```
User Taps "Create Event" Button
         │
         ▼
┌──────────────────────┐
│  CreateEventScreen   │
│                      │
│  onSubmit() {        │
│    context.read<     │
│      EventBloc>()    │
│      .add(           │
│        CreateEvent(  │
│          event: event│
│        )             │
│      );              │
│  }                   │
└──────────┬───────────┘
           │
           │ Event
           ▼
┌──────────────────────┐
│     EventBloc        │
│                      │
│  on<CreateEvent>(    │
│    (event, emit) {   │
│                      │
│  emit(EventLoading());
│                      │
│  final result =      │
│    await service     │
│      .createEvent(   │
│        event.event   │
│      );              │
│                      │
│  if (success) {      │
│    emit(             │
│      EventCreated(   │
│        event: result │
│      )               │
│    );                │
│  } else {            │
│    emit(             │
│      EventError(     │
│        message: error│
│      )               │
│    );                │
│  }                   │
│                      │
└──────────┬───────────┘
           │
           │ State
           ▼
┌──────────────────────┐
│  CreateEventScreen   │
│                      │
│  BlocListener<       │
│    EventBloc,        │
│    EventState>       │
│  (                   │
│    listener: (ctx, state) {
│      if (state is   │
│        EventCreated) {
│        Navigator     │
│          .pop(ctx);  │
│        showSuccess();│
│      }               │
│    }                 │
│  )                   │
└──────────────────────┘
```

---

## Deployment Architecture (Recommended)

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRODUCTION SETUP                            │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   Clients    │
│  (Mobile)    │
└──────┬───────┘
       │
       │ HTTPS
       ▼
┌──────────────┐
│     CDN      │  ← Static assets (images, etc.)
│  Cloudflare  │
└──────┬───────┘
       │
       │
       ▼
┌──────────────┐
│ Load Balancer│  ← Nginx or AWS ALB
└──────┬───────┘
       │
       ├──────────────────┬──────────────────┐
       ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  API Server │    │  API Server │    │  API Server │
│   Node.js   │    │   Node.js   │    │   Node.js   │
│  (Docker)   │    │  (Docker)   │    │  (Docker)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       └──────────────────┴──────────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  PostgreSQL │
                   │  + PostGIS  │
                   │  (Primary)  │
                   └──────┬──────┘
                          │
                          │ Replication
                          ▼
                   ┌─────────────┐
                   │  PostgreSQL │
                   │   (Replica) │
                   │  Read-only  │
                   └─────────────┘

External Services:
├── Supabase (Auth + Storage)
├── Yandex Maps API
├── Sentry (Error Tracking)
├── Prometheus + Grafana (Monitoring)
└── Firebase (Push Notifications - future)
```

---

## File Structure Visualization

```
andexevents/
│
├── backend/                         ← Node.js API
│   ├── prisma/
│   │   ├── schema.prisma           ← Database schema
│   │   └── migrations/             ← DB migrations
│   ├── src/
│   │   ├── controllers/            ← Request handlers
│   │   │   ├── event.controller.ts
│   │   │   ├── user.controller.ts
│   │   │   ├── match.controller.ts
│   │   │   └── upload.controller.ts
│   │   ├── services/               ← Business logic
│   │   │   ├── event.service.ts
│   │   │   ├── user.service.ts
│   │   │   └── match.service.ts
│   │   ├── routes/                 ← API routes
│   │   │   ├── event.routes.ts
│   │   │   ├── user.routes.ts
│   │   │   ├── match.routes.ts
│   │   │   └── upload.routes.ts
│   │   ├── middleware/             ← Auth, logging, etc.
│   │   │   ├── auth.middleware.ts
│   │   │   └── file-access.middleware.ts
│   │   ├── utils/                  ← Utilities
│   │   │   ├── logger.ts
│   │   │   ├── prisma.ts
│   │   │   └── user-storage.ts
│   │   └── index.ts                ← Entry point
│   ├── public/
│   │   └── uploads/                ← Uploaded files
│   │       ├── avatars/
│   │       └── events/
│   └── package.json
│
├── lib/                            ← Flutter app
│   ├── app/
│   │   └── app.dart                ← App initialization
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart     ← Configuration
│   │   └── utils/
│   │       └── image_utils.dart    ← Image processing
│   ├── data/
│   │   ├── models/                 ← Data models
│   │   │   ├── user_model.dart
│   │   │   ├── event_model.dart
│   │   │   └── participant_model.dart
│   │   └── services/               ← API services
│   │       ├── auth_service.dart
│   │       ├── event_service.dart
│   │       ├── user_service.dart
│   │       └── upload_service.dart
│   ├── presentation/
│   │   ├── auth/                   ← Auth screens
│   │   │   ├── bloc/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── events/                 ← Event screens
│   │   │   ├── bloc/
│   │   │   ├── event_list_screen.dart
│   │   │   ├── event_detail_screen.dart
│   │   │   ├── create_event_screen.dart
│   │   │   └── map_view.dart
│   │   ├── profile/                ← Profile screens
│   │   │   ├── bloc/
│   │   │   ├── profile_screen.dart
│   │   │   └── edit_profile_screen.dart
│   │   ├── matches/                ← Matching screens
│   │   │   ├── bloc/
│   │   │   └── swipe_screen.dart
│   │   └── widgets/                ← Reusable widgets
│   │       └── common/
│   └── main.dart                   ← Entry point
│
├── docs/                           ← Documentation
│   ├── architecture-analysis.md    ← This file
│   ├── architecture-diagrams.md    ← Visual diagrams
│   ├── local-storage-guide.md
│   └── supabase-image-upload-working-notes.md
│
└── README.md                       ← Project overview
```

---

## Performance Optimization Strategies

### Database Query Optimization

```
┌─────────────────────────────────────────────────────────────────┐
│              POSTGRESQL + POSTGIS OPTIMIZATION                   │
└─────────────────────────────────────────────────────────────────┘

1. Spatial Index (GIST)
   CREATE INDEX event_location_gist_idx 
   ON "Event" USING GIST ("locationGeo");
   
   Benefits:
   ├── 100x faster geospatial queries
   ├── Efficient ST_DWithin searches
   └── Scales to millions of records

2. Composite Indexes
   CREATE INDEX event_status_datetime_idx 
   ON "Event" (status, "dateTime" DESC);
   
   Use case:
   └── SELECT * FROM Event 
       WHERE status = 'APPROVED' 
       ORDER BY dateTime DESC;

3. Partial Indexes
   CREATE INDEX active_events_idx 
   ON "Event" (dateTime) 
   WHERE status = 'APPROVED' 
     AND "dateTime" > NOW();
   
   Benefits:
   ├── Smaller index size
   └── Faster queries for active events only

4. Query Analysis
   EXPLAIN ANALYZE
   SELECT * FROM "Event"
   WHERE ST_DWithin(
     "locationGeo",
     ST_MakePoint(37.6173, 55.7558)::geography,
     5000
   );
   
   Look for:
   ├── Index Scan (good)
   └── Seq Scan