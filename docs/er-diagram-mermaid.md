# ER-диаграмма Andex Events (Mermaid)

## Полная ER-диаграмма базы данных

```mermaid
erDiagram
    User ||--o{ Event : creates
    User ||--o{ Participant : "participates in"
    Event ||--o{ Participant : "has participants"
    User ||--o{ Match : "matches with (userA)"
    User ||--o{ Match : "matches with (userB)"
    User ||--o{ Notification : sends
    User ||--o{ Notification : receives

    User {
        uuid id PK
        string supabaseUid UK "Supabase Auth UID"
        string email UK
        string displayName
        string photoUrl
        text bio
        string[] interests
        jsonb socialLinks
        int age "18-100"
        string gender
        enum role "USER|MODERATOR|ADMIN"
        float lastLatitude "-90 to 90"
        float lastLongitude "-180 to 180"
        timestamp lastLocationUpdate
        boolean isProfileVisible
        boolean isLocationVisible
        int minAge
        int maxAge
        int maxDistance "default: 50000m"
        string fcmToken
        boolean isOnboardingCompleted
        timestamp createdAt
        timestamp updatedAt
    }

    Event {
        uuid id PK
        string title
        text description
        string category
        string location
        float latitude
        float longitude
        geography locationGeo "PostGIS Point"
        timestamp dateTime
        timestamp endDateTime
        decimal price "default: 0"
        string imageUrl
        boolean isOnline
        enum status "PENDING|APPROVED|REJECTED"
        text rejectionReason
        int maxParticipants
        int minAge
        int maxAge
        uuid createdById FK
        timestamp createdAt
        timestamp updatedAt
    }

    Participant {
        uuid id PK
        uuid userId FK
        uuid eventId FK
        enum status "INTERESTED|GOING"
        timestamp joinedAt
        timestamp updatedAt
    }

    Match {
        uuid id PK
        uuid userAId FK
        uuid userBId FK
        enum userAAction "LIKE|DISLIKE|SUPER_LIKE"
        enum userBAction "LIKE|DISLIKE|SUPER_LIKE"
        boolean isMutual
        timestamp matchedAt
        timestamp createdAt
        timestamp updatedAt
    }

    Notification {
        uuid id PK
        string type "MATCH|EVENT_REMINDER|etc"
        string title
        text body
        jsonb data
        uuid senderId FK
        uuid receiverId FK
        boolean isRead
        timestamp createdAt
    }
```

## Упрощенная диаграмма (только связи)

```mermaid
erDiagram
    User ||--o{ Event : "1:N creates"
    User }o--o{ Event : "N:M participates"
    Event ||--o{ Participant : "1:N has"
    User ||--o{ Participant : "1:N joins"
    User ||--o{ Match : "N:M userA"
    User ||--o{ Match : "N:M userB"
    User ||--o{ Notification : "1:N sends"
    User ||--o{ Notification : "1:N receives"

    User {
        uuid id
        string email
        string displayName
    }

    Event {
        uuid id
        string title
        geography locationGeo
        timestamp dateTime
    }

    Participant {
        uuid id
        uuid userId
        uuid eventId
    }

    Match {
        uuid id
        uuid userAId
        uuid userBId
        boolean isMutual
    }

    Notification {
        uuid id
        uuid receiverId
        boolean isRead
    }
```

## Диаграмма по модулям

### Модуль пользователей

```mermaid
erDiagram
    User {
        uuid id PK
        string supabaseUid UK
        string email UK
        string displayName
        string photoUrl
        text bio
        string[] interests
        jsonb socialLinks
        int age
        string gender
        enum role
        float lastLatitude
        float lastLongitude
        boolean isOnboardingCompleted
    }
```

### Модуль событий

```mermaid
erDiagram
    User ||--o{ Event : creates
    Event ||--o{ Participant : has
    User ||--o{ Participant : joins

    User {
        uuid id PK
        string displayName
    }

    Event {
        uuid id PK
        string title
        text description
        string category
        geography locationGeo
        timestamp dateTime
        decimal price
        string imageUrl
        enum status
        uuid createdById FK
    }

    Participant {
        uuid id PK
        uuid userId FK
        uuid eventId FK
        enum status
        timestamp joinedAt
    }
```

### Модуль матчинга

```mermaid
erDiagram
    User ||--o{ Match : "userA"
    User ||--o{ Match : "userB"

    User {
        uuid id PK
        string displayName
        string photoUrl
        string[] interests
        int age
    }

    Match {
        uuid id PK
        uuid userAId FK
        uuid userBId FK
        enum userAAction
        enum userBAction
        boolean isMutual
        timestamp matchedAt
    }
```

### Модуль уведомлений

```mermaid
erDiagram
    User ||--o{ Notification : sends
    User ||--o{ Notification : receives

    User {
        uuid id PK
        string displayName
    }

    Notification {
        uuid id PK
        string type
        string title
        text body
        jsonb data
        uuid senderId FK
        uuid receiverId FK
        boolean isRead
        timestamp createdAt
    }
```

## Диаграмма с кардинальностью

```mermaid
erDiagram
    User ||--o{ Event : "creates (1:N)"
    User }o--o{ Event : "participates (N:M via Participant)"
    Event ||--o{ Participant : "has (1:N)"
    User ||--o{ Participant : "joins (1:N)"
    User }o--o{ User : "matches (N:M via Match)"
    User ||--o{ Notification : "sends (1:N)"
    User ||--o{ Notification : "receives (1:N)"
```

## Как использовать

### 1. В GitHub
Просто вставьте код Mermaid в файл `.md` - GitHub автоматически отрендерит диаграмму.

### 2. В VS Code
Установите расширение: `Markdown Preview Mermaid Support`

### 3. Онлайн редактор
Используйте https://mermaid.live для редактирования и экспорта в PNG/SVG

### 4. В документации
```markdown
# Моя документация

## ER-диаграмма

\```mermaid
erDiagram
    User ||--o{ Event : creates
    ...
\```
```

## Легенда символов

### Кардинальность связей:
- `||--o{` - один к многим (1:N)
- `}o--o{` - многие ко многим (N:M)
- `||--||` - один к одному (1:1)
- `}o--||` - многие к одному (N:1)

### Типы полей:
- `PK` - Primary Key (первичный ключ)
- `FK` - Foreign Key (внешний ключ)
- `UK` - Unique Key (уникальный ключ)

### Типы данных:
- `uuid` - UUID
- `string` - VARCHAR/TEXT
- `text` - TEXT
- `int` - INTEGER
- `float` - FLOAT/DOUBLE
- `decimal` - DECIMAL
- `boolean` - BOOLEAN
- `timestamp` - TIMESTAMP
- `enum` - ENUM тип
- `jsonb` - JSONB (PostgreSQL)
- `geography` - PostGIS Geography

## Экспорт диаграммы

### В PNG (через mermaid.live):
1. Откройте https://mermaid.live
2. Вставьте код Mermaid
3. Нажмите "Download PNG"

### В SVG (через mermaid-cli):
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i er-diagram.mmd -o er-diagram.svg
```

### В PDF (через Pandoc):
```bash
pandoc er-diagram-mermaid.md -o er-diagram.pdf
```

## Примечания

### PostGIS Geography
`locationGeo` поле использует PostGIS тип `geography(Point, 4326)` для эффективных геопространственных запросов:
- ST_DWithin для поиска в радиусе
- ST_Distance для вычисления расстояния
- GIST индекс для оптимизации

### Триггеры
Автоматические триггеры в базе данных:
- `update_updated_at_column()` - обновление поля `updatedAt`
- `update_location_geo()` - генерация `locationGeo` из `latitude/longitude`
- `check_mutual_match()` - автоматическая установка `isMutual` в Match

### Каскадные удаления
- User → Event: CASCADE (удаление пользователя удаляет его события)
- User → Participant: CASCADE (удаление пользователя удаляет его участия)
- Event → Participant: CASCADE (удаление события удаляет участников)
- User → Match: CASCADE (удаление пользователя удаляет его матчи)
- User → Notification (receiver): CASCADE
- User → Notification (sender): SET NULL

## Дополнительные ресурсы

- **Mermaid документация:** https://mermaid.js.org/
- **ER диаграммы в Mermaid:** https://mermaid.js.org/syntax/entityRelationshipDiagram.html
- **Онлайн редактор:** https://mermaid.live
- **VS Code расширение:** Markdown Preview Mermaid Support

---

**Дата создания:** 2024-12-13  
**Версия:** 1.0  
**Проект:** Andex Events