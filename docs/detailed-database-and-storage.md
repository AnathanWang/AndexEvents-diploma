# Детальное описание базы данных, хранения изображений и интеграции Supabase

## СОДЕРЖАНИЕ

1. [Таблицы базы данных](#таблицы-базы-данных)
   - [User (Пользователи)](#1-таблица-user-пользователи)
   - [Event (События)](#2-таблица-event-события)
   - [Participant (Участники)](#3-таблица-participant-участники)
   - [Match (Матчи)](#4-таблица-match-матчи)
   - [Notification (Уведомления)](#5-таблица-notification-уведомления)
2. [Хранение изображений](#хранение-изображений)
3. [Интеграция Supabase](#интеграция-supabase)

---

## ТАБЛИЦЫ БАЗЫ ДАННЫХ

### 1. Таблица User (Пользователи)

#### Назначение
Таблица `User` хранит информацию о зарегистрированных пользователях приложения, включая профильные данные, настройки приватности и геолокацию.

#### Структура таблицы

```sql
CREATE TABLE "User" (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    "supabaseUid" VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    "displayName" VARCHAR(100),
    "photoUrl" TEXT,
    bio TEXT,
    interests TEXT[] DEFAULT '{}',
    "socialLinks" JSONB,
    age INTEGER CHECK (age >= 18 AND age <= 100),
    gender VARCHAR(50),
    role "UserRole" DEFAULT 'USER',
    "lastLatitude" DOUBLE PRECISION CHECK ("lastLatitude" >= -90 AND "lastLatitude" <= 90),
    "lastLongitude" DOUBLE PRECISION CHECK ("lastLongitude" >= -180 AND "lastLongitude" <= 180),
    "lastLocationUpdate" TIMESTAMP WITH TIME ZONE,
    "isProfileVisible" BOOLEAN DEFAULT TRUE,
    "isLocationVisible" BOOLEAN DEFAULT TRUE,
    "minAge" INTEGER,
    "maxAge" INTEGER,
    "maxDistance" INTEGER DEFAULT 50000,
    "fcmToken" TEXT,
    "isOnboardingCompleted" BOOLEAN DEFAULT FALSE,
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Детальное описание полей

| Поле | Тип | Ограничения | Назначение | Пример значения |
|------|-----|-------------|------------|-----------------|
| **id** | UUID | PRIMARY KEY | Уникальный идентификатор пользователя в системе | `550e8400-e29b-41d4-a716-446655440000` |
| **supabaseUid** | VARCHAR(255) | UNIQUE, NOT NULL | Идентификатор пользователя из Supabase Auth | `auth0\|507f1f77bcf86cd799439011` |
| **email** | VARCHAR(255) | UNIQUE, NOT NULL | Email для входа в систему | `ivan.petrov@example.com` |
| **displayName** | VARCHAR(100) | NULL | Отображаемое имя пользователя | `Иван Петров` |
| **photoUrl** | TEXT | NULL | URL фотографии профиля | `https://storage.supabase.co/avatars/user123.jpg` |
| **bio** | TEXT | NULL | Биография/описание пользователя | `Люблю путешествия и музыку` |
| **interests** | TEXT[] | DEFAULT '{}' | Массив интересов пользователя | `['музыка', 'спорт', 'кино']` |
| **socialLinks** | JSONB | NULL | Ссылки на соцсети | `{"instagram": "@user", "telegram": "@user"}` |
| **age** | INTEGER | CHECK (18-100) | Возраст пользователя | `25` |
| **gender** | VARCHAR(50) | NULL | Пол пользователя | `male`, `female`, `other` |
| **role** | UserRole | DEFAULT 'USER' | Роль в системе | `USER`, `MODERATOR`, `ADMIN` |
| **lastLatitude** | DOUBLE | CHECK (-90 to 90) | Последняя широта местоположения | `55.7558` |
| **lastLongitude** | DOUBLE | CHECK (-180 to 180) | Последняя долгота местоположения | `37.6173` |
| **lastLocationUpdate** | TIMESTAMP | NULL | Время последнего обновления локации | `2024-12-13 15:30:00+00` |
| **isProfileVisible** | BOOLEAN | DEFAULT TRUE | Видимость профиля для других | `true` |
| **isLocationVisible** | BOOLEAN | DEFAULT TRUE | Видимость геолокации | `true` |
| **minAge** | INTEGER | NULL | Минимальный возраст для матчинга | `20` |
| **maxAge** | INTEGER | NULL | Максимальный возраст для матчинга | `35` |
| **maxDistance** | INTEGER | DEFAULT 50000 | Радиус поиска в метрах | `50000` (50 км) |
| **fcmToken** | TEXT | NULL | Firebase Cloud Messaging токен для push | `fGH7dkP...` |
| **isOnboardingCompleted** | BOOLEAN | DEFAULT FALSE | Завершен ли онбординг | `true` |
| **createdAt** | TIMESTAMP | DEFAULT NOW() | Дата создания записи | `2024-01-15 10:00:00+00` |
| **updatedAt** | TIMESTAMP | DEFAULT NOW() | Дата последнего обновления | `2024-12-13 15:30:00+00` |

#### Индексы

```sql
-- Уникальные индексы
CREATE UNIQUE INDEX "User_supabaseUid_key" ON "User"("supabaseUid");
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- Индексы для поиска
CREATE INDEX "User_lastLatitude_lastLongitude_idx" 
    ON "User"("lastLatitude", "lastLongitude")
    WHERE "isOnboardingCompleted" = TRUE AND "isProfileVisible" = TRUE;

CREATE INDEX "User_role_idx" ON "User"(role);

-- Индекс для полнотекстового поиска (опционально)
CREATE INDEX "User_displayName_trgm_idx" ON "User" USING gin("displayName" gin_trgm_ops);
```

#### Связи

```
User ──1:N──> Event (создатель события)
User ──N:M──> Event (через Participant - участие в событиях)
User ──N:M──> User (через Match - матчи с другими пользователями)
User ──1:N──> Notification (отправленные уведомления)
User ──1:N──> Notification (полученные уведомления)
```

#### Триггеры

```sql
-- Автоматическое обновление updatedAt
CREATE TRIGGER update_user_updated_at 
    BEFORE UPDATE ON "User"
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
```

#### Бизнес-правила

1. **Уникальность email:** Каждый email может быть зарегистрирован только один раз
2. **Возрастное ограничение:** Пользователям должно быть не менее 18 лет
3. **Координаты:** Широта от -90 до 90, долгота от -180 до 180
4. **Каскадное удаление:** При удалении пользователя удаляются его события, участия, матчи и уведомления
5. **Радиус поиска:** По умолчанию 50 км, может быть изменен пользователем

#### Пример данных

```sql
INSERT INTO "User" (
    "supabaseUid", 
    email, 
    "displayName", 
    age, 
    gender, 
    interests, 
    "lastLatitude", 
    "lastLongitude",
    "isOnboardingCompleted"
) VALUES (
    'auth0|507f1f77bcf86cd799439011',
    'ivan.petrov@example.com',
    'Иван Петров',
    25,
    'male',
    ARRAY['музыка', 'спорт', 'путешествия'],
    55.7558,
    37.6173,
    TRUE
);
```

#### Prisma Schema

```prisma
model User {
  id            String   @id @default(uuid())
  supabaseUid   String   @unique
  email         String   @unique
  displayName   String?
  photoUrl      String?
  bio           String?
  interests     String[]
  socialLinks   Json?
  age           Int?
  gender        String?
  role          UserRole @default(USER)
  
  lastLatitude  Float?
  lastLongitude Float?
  lastLocationUpdate DateTime?
  
  isProfileVisible   Boolean @default(true)
  isLocationVisible  Boolean @default(true)
  minAge             Int?
  maxAge             Int?
  maxDistance        Int @default(50000)
  
  fcmToken      String?
  isOnboardingCompleted Boolean @default(false)
  
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  
  createdEvents         Event[] @relation("EventCreator")
  participations        Participant[]
  matchesAsUserA        Match[] @relation("MatchUserA")
  matchesAsUserB        Match[] @relation("MatchUserB")
  sentNotifications     Notification[] @relation("NotificationSender")
  receivedNotifications Notification[] @relation("NotificationReceiver")
  
  @@index([supabaseUid])
  @@index([email])
}

enum UserRole {
  USER
  MODERATOR
  ADMIN
}
```

---

### 2. Таблица Event (События)

#### Назначение
Таблица `Event` хранит информацию о событиях (концерты, выставки, спортивные мероприятия), создаваемых пользователями.

#### Структура таблицы

```sql
CREATE TABLE "Event" (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    location VARCHAR(500) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    "locationGeo" GEOGRAPHY(Point, 4326),
    "dateTime" TIMESTAMP WITH TIME ZONE NOT NULL,
    "endDateTime" TIMESTAMP WITH TIME ZONE,
    price DECIMAL(10,2) DEFAULT 0 CHECK (price >= 0),
    "imageUrl" TEXT,
    "isOnline" BOOLEAN DEFAULT FALSE,
    status "EventStatus" DEFAULT 'PENDING',
    "rejectionReason" TEXT,
    "maxParticipants" INTEGER,
    "minAge" INTEGER,
    "maxAge" INTEGER,
    "createdById" UUID REFERENCES "User"(id) ON DELETE CASCADE,
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Детальное описание полей

| Поле | Тип | Ограничения | Назначение | Пример значения |
|------|-----|-------------|------------|-----------------|
| **id** | UUID | PRIMARY KEY | Уникальный идентификатор события | `650e8400-e29b-41d4-a716-446655440001` |
| **title** | VARCHAR(200) | NOT NULL | Название события | `Концерт группы "Кино"` |
| **description** | TEXT | NOT NULL | Подробное описание | `Легендарные хиты в исполнении кавер-группы` |
| **category** | VARCHAR(50) | NOT NULL | Категория события | `музыка`, `спорт`, `искусство`, `образование` |
| **location** | VARCHAR(500) | NOT NULL | Текстовый адрес | `Москва, ул. Тверская, д. 1` |
| **latitude** | DOUBLE | NOT NULL | Широта места проведения | `55.7558` |
| **longitude** | DOUBLE | NOT NULL | Долгота места проведения | `37.6173` |
| **locationGeo** | GEOGRAPHY | NULL | PostGIS точка для геопоиска | `POINT(37.6173 55.7558)` |
| **dateTime** | TIMESTAMP | NOT NULL | Дата и время начала | `2024-12-20 19:00:00+00` |
| **endDateTime** | TIMESTAMP | NULL | Дата и время окончания | `2024-12-20 22:00:00+00` |
| **price** | DECIMAL(10,2) | CHECK (>=0) | Стоимость участия | `1500.00` (рубли) |
| **imageUrl** | TEXT | NULL | URL изображения события | `https://storage.supabase.co/events/event123.jpg` |
| **isOnline** | BOOLEAN | DEFAULT FALSE | Онлайн событие | `false` |
| **status** | EventStatus | DEFAULT 'PENDING' | Статус модерации | `PENDING`, `APPROVED`, `REJECTED` |
| **rejectionReason** | TEXT | NULL | Причина отклонения | `Недостаточно информации` |
| **maxParticipants** | INTEGER | NULL | Макс. количество участников | `100` |
| **minAge** | INTEGER | NULL | Мин. возраст для участия | `18` |
| **maxAge** | INTEGER | NULL | Макс. возраст для участия | `35` |
| **createdById** | UUID | FOREIGN KEY | ID создателя события | `550e8400-e29b-41d4-a716-446655440000` |
| **createdAt** | TIMESTAMP | DEFAULT NOW() | Дата создания | `2024-12-13 10:00:00+00` |
| **updatedAt** | TIMESTAMP | DEFAULT NOW() | Дата обновления | `2024-12-13 15:00:00+00` |

#### Индексы

```sql
-- Обычные B-tree индексы
CREATE INDEX "Event_status_idx" ON "Event"(status);
CREATE INDEX "Event_category_idx" ON "Event"(category);
CREATE INDEX "Event_dateTime_idx" ON "Event"("dateTime");
CREATE INDEX "Event_createdById_idx" ON "Event"("createdById");

-- Составные индексы для частых запросов
CREATE INDEX "Event_status_dateTime_idx" 
    ON "Event"(status, "dateTime" DESC);

CREATE INDEX "Event_category_status_idx" 
    ON "Event"(category, status)
    WHERE status = 'APPROVED';

-- GiST индекс для геопространственных запросов (КРИТИЧЕСКИ ВАЖНО!)
CREATE INDEX "Event_locationGeo_gist_idx" 
    ON "Event" USING GIST ("locationGeo");

-- Partial index для активных событий
CREATE INDEX "Event_active_events_idx" 
    ON "Event"("dateTime", status)
    WHERE status = 'APPROVED' AND "dateTime" > NOW();
```

#### Триггеры

```sql
-- Автоматическое обновление updatedAt
CREATE TRIGGER update_event_updated_at 
    BEFORE UPDATE ON "Event"
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Автоматическая генерация locationGeo из координат
CREATE OR REPLACE FUNCTION update_location_geo()
RETURNS TRIGGER AS $$
BEGIN
    NEW."locationGeo" = ST_SetSRID(
        ST_MakePoint(NEW.longitude, NEW.latitude), 
        4326
    )::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_location_geo 
    BEFORE INSERT OR UPDATE ON "Event"
    FOR EACH ROW 
    EXECUTE FUNCTION update_location_geo();
```

#### Категории событий

```sql
-- Рекомендуемые категории
CREATE TYPE "EventCategory" AS ENUM (
    'музыка',           -- Концерты, фестивали
    'спорт',            -- Спортивные мероприятия
    'искусство',        -- Выставки, галереи
    'образование',      -- Лекции, семинары
    'развлечения',      -- Вечеринки, клубы
    'технологии',       -- IT-митапы, хакатоны
    'бизнес',           -- Нетворкинг, конференции
    'кино',             -- Премьеры, кинопоказы
    'театр',            -- Спектакли, перформансы
    'еда',              -- Фуд-фестивали
    'природа',          -- Походы, пикники
    'благотворительность', -- Волонтерство
    'другое'            -- Прочее
);
```

#### Статусы событий

```sql
CREATE TYPE "EventStatus" AS ENUM (
    'PENDING',    -- Ожидает модерации
    'APPROVED',   -- Одобрено, видно пользователям
    'REJECTED'    -- Отклонено модератором
);
```

#### Связи

```
User ──1:N──> Event (создатель)
Event ──1:N──> Participant (участники)
```

#### Бизнес-правила

1. **Модерация:** Новые события имеют статус PENDING и требуют одобрения модератором
2. **Геоточка:** locationGeo автоматически генерируется из latitude/longitude
3. **Дата события:** Не может быть в прошлом
4. **Цена:** Не может быть отрицательной (бесплатные события = 0)
5. **Каскадное удаление:** При удалении события удаляются все записи участников

#### Пример данных

```sql
INSERT INTO "Event" (
    title,
    description,
    category,
    location,
    latitude,
    longitude,
    "dateTime",
    "endDateTime",
    price,
    "imageUrl",
    status,
    "createdById"
) VALUES (
    'Концерт группы "Кино"',
    'Легендарные хиты в исполнении кавер-группы. Приглашаем всех поклонников!',
    'музыка',
    'Москва, клуб "Космонавт", ул. Тверская, 1',
    55.7558,
    37.6173,
    '2024-12-20 19:00:00+00',
    '2024-12-20 22:00:00+00',
    1500.00,
    'https://storage.supabase.co/events/kino-concert.jpg',
    'APPROVED',
    '550e8400-e29b-41d4-a716-446655440000'
);
```

#### Геопространственные запросы

**Поиск событий в радиусе 5 км:**

```sql
SELECT 
    e.*,
    ST_Distance(
        e."locationGeo",
        ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography
    ) as distance_meters
FROM "Event" e
WHERE 
    e.status = 'APPROVED'
    AND ST_DWithin(
        e."locationGeo",
        ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography,
        5000  -- радиус в метрах
    )
ORDER BY distance_meters ASC
LIMIT 20;
```

**Важно:** В `ST_MakePoint(lon, lat)` долгота идёт первой!

#### Prisma Schema

```prisma
model Event {
  id          String   @id @default(uuid())
  title       String
  description String   @db.Text
  category    String
  
  location    String
  latitude    Float
  longitude   Float
  locationGeo Unsupported("geography(Point, 4326)")?
  
  dateTime    DateTime
  endDateTime DateTime?
  price       Float    @default(0)
  imageUrl    String?
  isOnline    Boolean  @default(false)
  
  status      EventStatus @default(PENDING)
  rejectionReason String?
  
  maxParticipants Int?
  minAge      Int?
  maxAge      Int?
  
  createdById String?
  createdBy   User? @relation("EventCreator", fields: [createdById], references: [id], onDelete: Cascade)
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  participants Participant[]
  
  @@index([createdById])
  @@index([status])
  @@index([dateTime])
  @@index([category])
}

enum EventStatus {
  PENDING
  APPROVED
  REJECTED
}
```

---

### 3. Таблица Participant (Участники)

#### Назначение
Таблица `Participant` реализует связь многие-ко-многим (N:M) между пользователями и событиями, хранит информацию об участии пользователей в событиях.

#### Структура таблицы

```sql
CREATE TABLE "Participant" (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    "userId" UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "eventId" UUID NOT NULL REFERENCES "Event"(id) ON DELETE CASCADE,
    status "ParticipantStatus" DEFAULT 'INTERESTED',
    "joinedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE("userId", "eventId")
);
```

#### Детальное описание полей

| Поле | Тип | Ограничения | Назначение | Пример значения |
|------|-----|-------------|------------|-----------------|
| **id** | UUID | PRIMARY KEY | Уникальный идентификатор записи | `750e8400-e29b-41d4-a716-446655440002` |
| **userId** | UUID | FOREIGN KEY, NOT NULL | ID пользователя | `550e8400-e29b-41d4-a716-446655440000` |
| **eventId** | UUID | FOREIGN KEY, NOT NULL | ID события | `650e8400-e29b-41d4-a716-446655440001` |
| **status** | ParticipantStatus | DEFAULT 'INTERESTED' | Статус участия | `INTERESTED`, `GOING` |
| **joinedAt** | TIMESTAMP | DEFAULT NOW() | Дата присоединения | `2024-12-13 10:00:00+00` |
| **updatedAt** | TIMESTAMP | DEFAULT NOW() | Дата изменения статуса | `2024-12-14 12:00:00+00` |

#### Статусы участия

```sql
CREATE TYPE "ParticipantStatus" AS ENUM (
    'INTERESTED',  -- Интересуюсь событием
    'GOING'        -- Точно пойду
);
```

**Различия:**
- **INTERESTED** — пользователь заинтересован, но ещё не уверен
- **GOING** — пользователь подтвердил участие

#### Индексы

```sql
-- Индексы для внешних ключей (для JOIN'ов)
CREATE INDEX "Participant_userId_idx" ON "Participant"("userId");
CREATE INDEX "Participant_eventId_idx" ON "Participant"("eventId");

-- Уникальный составной индекс (пользователь + событие)
CREATE UNIQUE INDEX "Participant_userId_eventId_key" 
    ON "Participant"("userId", "eventId");

-- Индекс для фильтрации по статусу
CREATE INDEX "Participant_status_idx" ON "Participant"(status);

-- Составной индекс для запросов типа "кто идёт на событие"
CREATE INDEX "Participant_eventId_status_idx" 
    ON "Participant"("eventId", status)
    WHERE status = 'GOING';
```

#### Триггеры

```sql
-- Автоматическое обновление updatedAt
CREATE TRIGGER update_participant_updated_at 
    BEFORE UPDATE ON "Participant"
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
```

#### Ограничения

```sql
-- Уникальность: пользователь может участвовать в событии только один раз
ALTER TABLE "Participant" 
    ADD CONSTRAINT "Participant_userId_eventId_unique" 
    UNIQUE("userId", "eventId");

-- Каскадное удаление
-- При удалении пользователя → удаляются его участия
-- При удалении события → удаляются все записи участников
```

#### Связи

```
User ──1:N──> Participant
Event ──1:N──> Participant

Participant является промежуточной таблицей для связи N:M
```

#### Бизнес-правила

1. **Уникальность участия:** Пользователь может присоединиться к событию только один раз
2. **Изменение статуса:** Пользователь может изменить статус с INTERESTED на GOING и обратно
3. **Отмена участия:** Удаление записи = отказ от участия
4. **Подсчёт участников:** Количество записей с eventId = количество заинтересованных

#### Пример данных

```sql
-- Иван интересуется концертом
INSERT INTO "Participant" ("userId", "eventId", status)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    '650e8400-e29b-41d4-a716-446655440001',
    'INTERESTED'
);

-- Мария точно пойдёт на концерт
INSERT INTO "Participant" ("userId", "eventId", status)
VALUES (
    '550e8400-e29b-41d4-a716-446655440003',
    '650e8400-e29b-41d4-a716-446655440001',
    'GOING'
);
```

#### Полезные запросы

**Список участников события:**

```sql
SELECT 
    u.id,
    u."displayName",
    u."photoUrl",
    p.status,
    p."joinedAt"
FROM "Participant" p
JOIN "User" u ON p."userId" = u.id
WHERE p."eventId" = '650e8400-e29b-41d4-a716-446655440001'
ORDER BY p."joinedAt" DESC;
```

**Количество участников по статусам:**

```sql
SELECT 
    e.title,
    COUNT(*) FILTER (WHERE p.status = 'INTERESTED') as interested_count,
    COUNT(*) FILTER (WHERE p.status = 'GOING') as going_count,
    COUNT(*) as total_count
FROM "Event" e
LEFT JOIN "Participant" p ON e.id = p."eventId"
WHERE e.id = '650e8400-e29b-41d4-a716-446655440001'
GROUP BY e.id, e.title;
```

**События, в которых участвует пользователь:**

```sql
SELECT 
    e.*,
    p.status as my_status,
    p."joinedAt"
FROM "Event" e
JOIN "Participant" p ON e.id = p."eventId"
WHERE p."userId" = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY e."dateTime" ASC;
```

#### Prisma Schema

```prisma
model Participant {
  id        String   @id @default(uuid())
  
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  eventId   String
  event     Event    @relation(fields: [eventId], references: [id], onDelete: Cascade)
  
  status    ParticipantStatus @default(INTERESTED)
  
  joinedAt  DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@unique([userId, eventId])
  @@index([userId])
  @@index([eventId])
}

enum ParticipantStatus {
  INTERESTED
  GOING
}
```

---

### 4. Таблица Match (Матчи)

#### Назначение
Таблица `Match` реализует систему знакомств в стиле Tinder — хранит информацию о взаимодействиях пользователей (лайки, дизлайки) и взаимных симпатиях.

#### Структура таблицы

```sql
CREATE TABLE "Match" (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    "userAId" UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "userBId" UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "userAAction" "MatchAction",
    "userBAction" "MatchAction",
    "isMutual" BOOLEAN DEFAULT FALSE,
    "matchedAt" TIMESTAMP WITH TIME ZONE,
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE("userAId", "userBId"),
    CHECK("userAId" != "userBId")
);
```

#### Детальное описание полей

| Поле | Тип | Ограничения | Назначение | Пример значения |
|------|-----|-------------|------------|-----------------|
| **id** | UUID | PRIMARY KEY | Уникальный идентификатор матча | `850e8400-e29b-41d4-a716-446655440003` |
| **userAId** | UUID | FOREIGN KEY, NOT NULL | ID первого пользователя | `550e8400-e29b-41d4-a716-446655440000` |
| **userBId** | UUID | FOREIGN KEY, NOT NULL | ID второго пользователя | `550e8400-e29b-41d4-a716-446655440003` |
| **userAAction** | MatchAction | NULL | Действие userA | `LIKE`, `DISLIKE`, `SUPER_LIKE` |
| **userBAction** | MatchAction | NULL | Действие userB | `LIKE`, `DISLIKE`, `SUPER_LIKE` |
| **isMutual** | BOOLEAN | DEFAULT FALSE | Взаимная симпатия | `true` (если оба LIKE) |
| **matchedAt** | TIMESTAMP | NULL | Дата/время матча | `2024-12-13 15:30:00+00` |
| **createdAt** | TIMESTAMP | DEFAULT NOW() | Дата создания | `2024-12-13 10:00:00+00` |
| **updatedAt** | TIMESTAMP | DEFAULT NOW() | Дата обновления | `2024-12-13 15:30:00+00` |

#### Типы действий

```sql
CREATE TYPE "MatchAction" AS ENUM (
    'LIKE',        -- Обычный лайк (свайп вправо)
    'DISLIKE',     -- Дизлайк (свайп влево)
    'SUPER_LIKE'   -- Супер-лайк (особый интерес)
);
```

#### Индексы

```sql
-- Индексы для внешних ключей
CREATE INDEX "Match_userAId_idx" ON "Match"("userAId");
CREATE INDEX "Match_userBId_idx" ON "Match"("userBId");

-- Уникальный составной индекс (один матч на пару)
CREATE UNIQUE INDEX "Match_userAId_userBId_key" 
    ON "Match"("userAId", "userBId");

-- Индекс для поиска взаимных матчей
CREATE INDEX "Match_isMutual_matchedAt_idx" 
    ON "Match"("isMutual", "matchedAt" DESC)
    WHERE "isMutual" = TRUE;

-- Индексы для поиска действий пользователя
CREATE INDEX "Match_userAId_userAAction_idx" 
    ON "Match"("userAId", "userAAction");
```

#### Триггеры

```sql
-- Автоматическое обновление updatedAt
CREATE TRIGGER update_match_updated_at 
    BEFORE UPDATE ON "Match"
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Автоматическая проверка взаимности
CREATE OR REPLACE FUNCTION check_mutual_match()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем, оба ли пользователя поставили LIKE
    IF NEW."userAAction" = 'LIKE' AND NEW."userBAction" = 'LIKE' THEN
        NEW."isMutual" = TRUE;
        NEW."matchedAt" = NOW();
    ELSE
        NEW."isMutual" = FALSE;
        NEW."matchedAt" = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER match_mutual_check 
    BEFORE INSERT OR UPDATE ON "Match"
    FOR EACH ROW 
    EXECUTE FUNCTION check_mutual_match();
```

#### Ограничения

```sql
-- Пользователь не может матчиться сам с собой
ALTER TABLE "Match" 
    ADD CONSTRAINT "Match_no_self_match" 
    CHECK("userAId" != "userBId");

-- Только одна запись на пару пользователей
ALTER TABLE "Match" 
    ADD CONSTRAINT "Match_userAId_userBId_unique" 
    UNIQUE("userAId", "userBId");
```

#### Связи

```
User ──1:N──> Match (как userA)
User ──1:N──> Match (как userB)

Каждый матч связывает двух пользователей
```

#### Логика работы

**Сценарий 1: Первый лайк**
1. User A свайпает вправо на User B
2. Создаётся запись: `userAId=A, userBId=B, userAAction=LIKE, userBAction=NULL`
3. `isMutual=FALSE` (ещё не взаимно)

**Сценарий 2: Взаимный лайк**
1. User B тоже свайпает вправо на User A
2. Обновляется запись: `userBAction=LIKE`
3. Триггер автоматически устанавливает `isMutual=TRUE, matchedAt=NOW()`
4. Оба пользователя получают уведомление "It's a Match!"

**Сценарий 3: Дизлайк**
1. User B свайпает влево
2. Обновляется: `userBAction=DISLIKE`
3. `isMutual` остаётся `FALSE`

#### Пример данных

```sql
-- Иван лайкнул Марию
INSERT INTO "Match" ("userAId", "userBId", "userAAction")
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',  -- Иван
    '550e8400-e29b-41d4-a716-446655440003',  -- Мария
    'LIKE'
);

-- Мария тоже лайкнула Ивана (взаимный матч!)
UPDATE "Match" 
SET "userBAction" = 'LIKE'
WHERE "userAId" = '550e8400-e29b-41d4-a716-446655440000'
  AND "userBId" = '550e8400-e29b-41d4-a716-446655440003';

-- Триггер автоматически установит isMutual=TRUE и matchedAt
```

#### Полезные запросы

**Все взаимные матчи пользователя:**

```sql
SELECT 
    CASE 
        WHEN m."userAId" = '550e8400-e29b-41d4-a716-446655440000' 
        THEN u2.id 
        ELSE u1.id 
    END as matched_user_id,
    CASE 
        WHEN m."userAId" = '550e8400-e29b-41d4-a716-446655440000' 
        THEN u2."displayName" 
        ELSE u1."displayName" 
    END as matched_user_name,
    m."matchedAt"
FROM "Match" m
JOIN "User" u1 ON m."userAId" = u1.id
JOIN "User" u2 ON m."userBId" = u2.id
WHERE 
    m."isMutual" = TRUE
    AND (
        m."userAId" = '550e8400-e29b-41d4-a716-446655440000'
        OR m."userBId" = '550e8400-e29b-41d4-a716-446655440000'
    )
ORDER BY m."matchedAt" DESC;
```

**Подсчёт матчей пользователя:**

```sql
SELECT 
    COUNT(*) FILTER (WHERE "isMutual" = TRUE) as mutual_matches,
    COUNT(*) FILTER (WHERE "userAAction" = 'LIKE') as outgoing_likes,
    COUNT(*) FILTER (WHERE "userAAction" = 'SUPER_LIKE') as super_likes
FROM "Match"
WHERE "userAId" = '550e8400-e29b-41d4-a716-446655440000';
```

#### Prisma Schema

```prisma
model Match {
  id        String   @id @default(uuid())
  
  userAId   String
  userA     User     @relation("MatchUserA", fields: [userAId], references: [id], onDelete: Cascade)
  
  userBId   String
  userB     User     @relation("MatchUserB", fields: [userBId], references: [id], onDelete: Cascade)
  
  userAAction MatchAction?
  userBAction MatchAction?
  
  isMutual  Boolean  @default(false)
  matchedAt DateTime?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@unique([userAId, userBId])
  @@index([userAId])
  @@index([userBId])
  @@index([isMutual])
}

enum MatchAction {
  LIKE
  DISLIKE
  SUPER_LIKE
}
```

---

### 5. Таблица Notification (Уведомления)

#### Назначение
Таблица `Notification` хранит системные уведомления для пользователей (новые матчи, напоминания о событиях, одобрение модератором и т.д.).

#### Структура таблицы

```sql
CREATE TABLE "Notification" (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    "senderId" UUID REFERENCES "User"(id) ON DELETE SET NULL,
    "receiverId" UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "isRead" BOOLEAN DEFAULT FALSE,
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Детальное описание полей

| Поле | Тип | Ограничения | Назначение | Пример значения |
|------|-----|-------------|------------|-----------------|
| **id** | UUID | PRIMARY KEY | Уникальный идентификатор | `950e8400-e29b-41d4-a716-446655440004` |
| **type** | VARCHAR(50) | NOT NULL | Тип уведомления | `MATCH`, `EVENT_REMINDER`, `EVENT_APPROVED` |
| **title** | VARCHAR(200) | NOT NULL | Заголовок уведомления | `It's a Match!` |
| **body** | TEXT | NOT NULL | Текст уведомления | `Вы понравились друг другу с Марией!` |
| **data** | JSONB | NULL | Дополнительные данные | `{"matchId": "...", "userId": "..."}` |
| **senderId** | UUID | FOREIGN KEY | ID отправителя | `550e8400-e29b-41d4-a716-446655440003` |
| **receiverId** | UUID | FOREIGN KEY, NOT NULL | ID получателя | `550e8400-e29b-41d4-a716-446655440000` |
| **isRead** | BOOLEAN | DEFAULT FALSE | Прочитано ли | `false` |
| **createdAt** | TIMESTAMP | DEFAULT NOW() | Дата создания | `2024-12-13 15:30:00+00` |

#### Типы уведомлений

```sql
-- Рекомендуемые типы (можно расширять)
-- MATCH - новый взаимный матч
-- EVENT_REMINDER - напоминание о событии
-- EVENT_APPROVED - событие одобрено модератором
-- EVENT_REJECTED - событие отклонено
-- NEW_PARTICIPANT - новый участник вашего события
-- EVENT_CANCELLED - событие отменено
-- MESSAGE - новое сообщение (для будущего чата)
```

#### Индексы

```sql
-- Индексы для быстрого поиска уведомлений пользователя
CREATE INDEX "Notification_receiverId_idx" 
    ON "Notification"("receiverId");

CREATE INDEX "Notification_isRead_idx" 
    ON "Notification"("isRead");

CREATE INDEX "Notification_type_idx" 
    ON "Notification"(type);

-- Составной индекс для непрочитанных уведомлений
CREATE INDEX "Notification_receiverId_isRead_createdAt_idx" 
    ON "Notification"("receiverId", "isRead", "createdAt" DESC)
    WHERE "isRead" = FALSE;

-- Индекс для отправителя (опционально)
CREATE INDEX "Notification_senderId_idx" 
    ON "Notification"("senderId")
    WHERE "senderId" IS NOT NULL;
```

#### Связи

```
User ──1:N──> Notification (отправитель)
User ──1:N──> Notification (получатель)
```

#### Политика удаления

```sql
-- При удалении получателя → удаляется уведомление
ON DELETE CASCADE для receiverId

-- При удалении отправителя → senderId становится NULL
ON DELETE SET NULL для senderId
```

#### Примеры уведомлений

**1. Новый матч:**

```sql
INSERT INTO "Notification" (type, title, body, data, "senderId", "receiverId")
VALUES (
    'MATCH',
    'It''s a Match! 💕',
    'Вы понравились друг другу с Марией!',
    jsonb_build_object(
        'matchId', '850e8400-e29b-41d4-a716-446655440003',
        'userId', '550e8400-e29b-41d4-a716-446655440003',
        'displayName', 'Мария'
    ),
    '550e8400-e29b-41d4-a716-446655440003',  -- Мария
    '550e8400-e29b-41d4-a716-446655440000'   -- Иван
);
```

**2. Напоминание о событии:**

```sql
INSERT INTO "Notification" (type, title, body, data, "receiverId")
VALUES (
    'EVENT_REMINDER',
    'Событие завтра! 🎉',
    'Не забудьте: "Концерт группы Кино" завтра в 19:00',
    jsonb_build_object(
        'eventId', '650e8400-e29b-41d4-a716-446655440001',
        'dateTime', '2024-12-20T19:00:00Z',
        'location', 'Москва, клуб "Космонавт"'
    ),
    '550e8400-e29b-41d4-a716-446655440000'
);
```

**3. Одобрение события:**

```sql
INSERT INTO "Notification" (type, title, body, data, "receiverId")
VALUES (
    'EVENT_APPROVED',
    'Ваше событие одобрено ✅',
    'Событие "Концерт группы Кино" прошло модерацию и теперь видно всем пользователям',
    jsonb_build_object(
        'eventId', '650e8400-e29b-41d4-a716-446655440001'
    ),
    '550e8400-e29b-41d4-a716-446655440000'
);
```

#### Полезные запросы

**Непрочитанные уведомления пользователя:**

```sql
SELECT 
    n.*,
    u."displayName" as sender_name,
    u."photoUrl" as sender_photo
FROM "Notification" n
LEFT JOIN "User" u ON n."senderId" = u.id
WHERE 
    n."receiverId" = '550e8400-e29b-41d4-a716-446655440000'
    AND n."isRead" = FALSE
ORDER BY n."createdAt" DESC;
```

**Подсчёт непрочитанных:**

```sql
SELECT COUNT(*) as unread_count
FROM "Notification"
WHERE 
    "receiverId" = '550e8400-e29b-41d4-a716-446655440000'
    AND "isRead" = FALSE;
```

**Отметить все как прочитанные:**

```sql
UPDATE "Notification"
SET "isRead" = TRUE
WHERE 
    "receiverId" = '550e8400-e29b-41d4-a716-446655440000'
    AND "isRead" = FALSE;
```

**Удалить старые прочитанные (> 30 дней):**

```sql
DELETE FROM "Notification"
WHERE 
    "isRead" = TRUE
    AND "createdAt" < NOW() - INTERVAL '30 days';
```

#### Структура данных в JSONB

```json
{
  // Для MATCH
  "matchId": "uuid",
  "userId": "uuid",
  "displayName": "string",
  "photoUrl": "url"
}

{
  // Для EVENT_REMINDER
  "eventId": "uuid",
  "dateTime": "ISO8601",
  "location": "string"
}

{
  // Для EVENT_APPROVED/REJECTED
  "eventId": "uuid",
  "rejectionReason": "string" // только для REJECTED
}

{
  // Для NEW_PARTICIPANT
  "eventId": "uuid",
  "userId": "uuid",
  "displayName": "string",
  "status": "GOING" | "INTERESTED"
}
```

#### Prisma Schema

```prisma
model Notification {
  id          String   @id @default(uuid())
  
  type        String
  title       String
  body        String   @db.Text
  data        Json?
  
  senderId    String?
  sender      User?    @relation("NotificationSender", fields: [senderId], references: [id], onDelete: SetNull)
  
  receiverId  String
  receiver    User     @relation("NotificationReceiver", fields: [receiverId], references: [id], onDelete: Cascade)
  
  isRead      Boolean  @default(false)
  
  createdAt   DateTime @default(now())
  
  @@index([receiverId])
  @@index([isRead])
  @@index([type])
}
```

---

## ХРАНЕНИЕ ИЗОБРАЖЕНИЙ

### Обзор системы хранения

В проекте "Andex Events" используется **гибридный подход** к хранению изображений с возможностью выбора между несколькими вариантами:

1. **Supabase Storage** (основной, рекомендуемый)
2. **Локальное хранилище на сервере** (альтернатива)
3. **Локальное хранилище на устройстве** (для offline режима)

### 1. Supabase Storage (Рекомендуется)

#### Архитектура

```
┌─────────────┐                    ┌──────────────────┐
│   Flutter   │                    │    Supabase      │
│     App     │─────Upload────────>│    Storage       │
│             │                    │                  │
│             │<────URL────────────│  ┌─────────────┐ │
│             │                    │  │  avatars/   │ │
│             │                    │  │  events/    │ │
└─────────────┘                    │  └─────────────┘ │
                                   └──────────────────┘
```

#### Структура бакетов

```
Supabase Storage
├── avatars/ (Public)
│   ├── user1-timestamp.jpg
│   ├── user2-timestamp.jpg
│   └── user3-timestamp.webp
│
└── events/ (Public)
    ├── event1-timestamp.jpg
    ├── event2-timestamp.jpg
    └── event3-timestamp.webp
```

#### Настройка бакетов в Supabase

**1. Создание бакетов:**

```sql
-- В Supabase Dashboard → Storage → Create bucket

-- Bucket: avatars
-- Public: true
-- File size limit: 5 MB
-- Allowed MIME types: image/jpeg, image/png, image/webp

-- Bucket: events
-- Public: true
-- File size limit: 10 MB
-- Allowed MIME types: image/jpeg, image/png, image/webp
```

**2. Storage Policies (RLS):**

```sql
-- Политика: Все могут читать
CREATE POLICY "Public Access" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars' OR bucket_id = 'events');

-- Политика: Только аутентифицированные могут загружать
CREATE POLICY "Authenticated users can upload" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id IN ('avatars', 'events') 
    AND auth.role() = 'authenticated'
  );

-- Политика: Пользователи могут удалять только свои файлы
CREATE POLICY "Users can delete own files" ON storage.objects
  FOR DELETE
  USING (
    bucket_id IN ('avatars', 'events')
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

#### Реализация в Flutter

**Сервис загрузки:**

```dart
// lib/data/services/upload_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/image_utils.dart';

class ProgressUploadService {
  final SupabaseClient _supabase;

  ProgressUploadService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Загрузить фото профиля
  Future<String> uploadProfilePhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [Upload] Начинаем загрузку аватара...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // 1. Сжатие изображения
      print('🔵 [Upload] Сжимаем изображение...');
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(
        originalFile,
        quality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      // 2. Проверка размера
      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 5MB, '
          'ваш: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)'
        );
      }

      // 3. Генерация уникального имени
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = filePath.split('.').last.toLowerCase();
      final fileName = '$timestamp.$extension';
      final path = 'avatars/$fileName';

      print('🔵 [Upload] Загружаем на Supabase: $path');

      // 4. Загрузка файла
      final fileBytes = await compressedFile.readAsBytes();
      
      await _supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: 'image/$extension',
            upsert: true,
          ),
        );

      print('🟢 [Upload] Файл загружен успешно');

      // 5. Получение публичного URL
      final url = _supabase.storage
        .from('avatars')
        .getPublicUrl(path);
      
      print('🟢 [Upload] URL: $url');
      onProgress?.call(1.0);

      return url;
    } catch (e) {
      print('🔴 [Upload] Ошибка: $e');
      rethrow;
    }
  }

  /// Загрузить фото события
  Future<String> uploadEventPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [Upload] Начинаем загрузку фото события...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // 1. Сжатие (более высокое качество для событий)
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(
        originalFile,
        quality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      // 2. Проверка размера
      final fileSize = await compressedFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 10MB, '
          'ваш: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)'
        );
      }

      // 3. Генерация имени
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = filePath.split('.').last.toLowerCase();
      final fileName = '$timestamp.$extension';
      final path = 'events/$fileName';

      print('🔵 [Upload] Загружаем на Supabase: $path');

      // 4. Загрузка
      final fileBytes = await compressedFile.readAsBytes();
      
      await _supabase.storage
        .from('events')
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: 'image/$extension',
            upsert: true,
          ),
        );

      // 5. URL
      final url = _supabase.storage
        .from('events')
        .getPublicUrl(path);
      
      print('🟢 [Upload] Фото события загружено: $url');
      onProgress?.call(1.0);

      return url;
    } catch (e) {
      print('🔴 [Upload] Ошибка: $e');
      rethrow;
    }
  }

  /// Удалить файл
  Future<void> deleteFile(String fileUrl, String bucket) async {
    try {
      // Извлекаем путь файла из URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.last;
      
      await _supabase.storage
        .from(bucket)
        .remove([fileName]);
      
      print('🟢 [Upload] Файл удалён: $fileName');
    } catch (e) {
      print('🔴 [Upload] Ошибка удаления: $e');
      rethrow;
    }
  }
}
```

**Утилита для сжатия изображений:**

```dart
// lib/core/utils/image_utils.dart
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  /// Сжатие изображения
  static Future<File> compressImage(
    File file, {
    int quality = 70,
    int maxWidth = 1200,
    int maxHeight = 1200,
  }) async {
    try {
      print('🔵 [ImageUtils] Начинаем сжатие...');
      print('🔵 [ImageUtils] Оригинал: ${await file.length()} bytes');

      // Временная директория
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      // Сжатие с таймаутом
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      ).timeout(
        Duration(seconds: 20),
        onTimeout: () {
          print('⚠️ [ImageUtils] Таймаут сжатия, используем оригинал');
          return file as XFile?;
        },
      );

      if (result == null) {
        print('⚠️ [ImageUtils] Сжатие вернуло null, используем оригинал');
        return file;
      }

      final compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();
      
      print('🟢 [ImageUtils] Сжато до: $compressedSize bytes');
      print('🟢 [ImageUtils] Экономия: ${((1 - compressedSize / await file.length()) * 100).toStringAsFixed(1)}%');

      return compressedFile;
    } catch (e) {
      print('🔴 [ImageUtils] Ошибка сжатия: $e');
      print('⚠️ [ImageUtils] Используем оригинальный файл');
      return file;
    }
  }

  /// Определение MIME типа по расширению
  static String getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
```

#### Пример использования в BLoC

```dart
// Загрузка аватара при редактировании профиля
Future<void> _onUploadAvatar(
  UploadAvatarEvent event,
  Emitter<ProfileState> emit,
) async {
  try {
    emit(ProfileUploading());

    // Загрузка на Supabase
    final uploadService = ProgressUploadService();
    final imageUrl = await uploadService.uploadProfilePhoto(
      event.filePath,
      onProgress: (progress) {
        print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
      },
    );

    // Обновление профиля с новым URL