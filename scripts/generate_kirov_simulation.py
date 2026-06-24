#!/usr/bin/env python3
"""Generate SQL seed: users + events across Kirov for map/feed/match testing."""

from __future__ import annotations

import random
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scripts" / "seed_kirov_simulation.sql"

# Kirov city bounding box (approx.)
LAT_MIN, LAT_MAX = 58.555, 58.645
LON_MIN, LON_MAX = 49.580, 49.720

USER_COUNT = 60
EVENT_COUNT = 40

NAMES_F = [
    "Алина", "Вика", "Дарья", "Елена", "Ирина", "Катя", "Лиза", "Мария",
    "Настя", "Оля", "Полина", "Соня", "Таня", "Юля", "Яна", "Вера",
    "Ксюша", "Лена", "Мила", "Света",
]
NAMES_M = [
    "Артём", "Борис", "Влад", "Глеб", "Денис", "Егор", "Иван", "Кирилл",
    "Лёша", "Максим", "Никита", "Олег", "Павел", "Роман", "Сергей", "Тимур",
    "Фёдор", "Юра", "Ярослав", "Илья",
]

INTERESTS = [
    "Музыка", "Спорт", "Кино", "IT", "Искусство", "Книги", "Еда",
    "Путешествия", "Фотография", "Мода", "Танцы", "Игры",
]

PHOTOS = [
    "/uploads/photos/seed/photo-1494790108377-be9c29b29330.jpg",
    "/uploads/photos/seed/photo-1500648767791-00dcc994a43e.jpg",
    "/uploads/photos/seed/photo-1544005313-94ddf0286df2.jpg",
    "/uploads/photos/seed/photo-1506794778202-cad84cf45f1d.jpg",
    "/uploads/photos/seed/photo-1438761681033-6461ffad8d80.jpg",
    "/uploads/photos/seed/photo-1506277886164-e25aa3f4ef7f.jpg",
    "/uploads/photos/seed/photo-1529626455594-4ff0802cfb7e.jpg",
    "/uploads/photos/seed/photo-1534528741775-53994a69daeb.jpg",
    "/uploads/photos/seed/photo-1539571696357-5a69c17a67c6.jpg",
    "/uploads/photos/seed/photo-1524504388940-b1c1722653e1.jpg",
    "/uploads/photos/seed/photo-1504257432389-52343af06ae3.jpg",
    "/uploads/photos/seed/photo-1488426862026-3ee34a7d66df.jpg",
]

EVENT_IMAGES = [
    "/uploads/events/seed/demo-jazz-party.jpg",
    "/uploads/events/seed/demo-run.jpg",
    "/uploads/events/seed/demo-art.jpg",
    "/uploads/events/seed/demo-tech.jpg",
    "",
]

CATEGORIES = [
    ("concert", "Концерт"),
    ("sport", "Спорт"),
    ("exhibition", "Выставка"),
    ("conference", "Конференция"),
    ("party", "Вечеринка"),
    ("theater", "Театр"),
    ("cinema", "Кино"),
    ("other", "Встреча"),
]

STREETS = [
    "набережная Грина", "пл. Островского", "ул. Ленина", "ул. Воровского",
    "ул. Карла Маркса", "мкр. Ломовой", "мкр. Нововятск", "мкр. Дороничи",
    "ул. Московская", "ул. Спасская", "пр. Октябрьский", "ул. Володарского",
    "мкр. Красный Химик", "мкр. Радужный", "ул. Красноармейская",
]

EVENT_TITLES = {
    "concert": [
        "Акустический вечер", "Живой джаз", "Кавер-группа у Вятки",
        "Open mic", "Концерт местных музыкантов",
    ],
    "sport": [
        "Утренний забег", "Волейбол в парке", "Йога на свежем воздухе",
        "Тренировка по бегу 5 км", "Стритбол на площадке",
    ],
    "exhibition": [
        "Выставка фотографии", "Арт-ярмарка", "Экспозиция молодых художников",
        "Галерея современного искусства", "Фотовыставка «Вятка»",
    ],
    "conference": [
        "IT-митап", "Мобильная разработка", "Стартап-питч",
        "Нетворкинг предпринимателей", "Встреча разработчиков",
    ],
    "party": [
        "House-party", "DJ-set в центре", "Вечеринка у друзей",
        "Танцевальная ночь", "Afterparty",
    ],
    "theater": [
        "Спектакль в театре", "Импровизация", "Читка пьесы",
    ],
    "cinema": [
        "Кинопоказ под открытым небом", "Просмотр артхауса", "Киноклуб",
    ],
    "other": [
        "Настольные игры", "Квест по городу", "Пикник в парке",
        "Кофе и нетворкинг", "Блошиный рынок",
    ],
}


def scatter(rng: random.Random, i: int) -> tuple[float, float]:
    lat = LAT_MIN + (rng.random() * (LAT_MAX - LAT_MIN))
    lon = LON_MIN + (rng.random() * (LON_MAX - LON_MIN))
    # Slight grid jitter so markers don't fully overlap
    lat += (i % 7) * 0.0004
    lon += (i % 11) * 0.0005
    return round(lat, 6), round(lon, 6)


def sql_str(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_array(items: list[str]) -> str:
    inner = ", ".join(sql_str(x) for x in items)
    return f"ARRAY[{inner}]::TEXT[]"


def main() -> None:
    rng = random.Random(20260624)

    user_rows: list[str] = []
    user_ids: list[str] = []

    for i in range(1, USER_COUNT + 1):
        uid = f"fake-match-sim-{i:03d}"
        user_ids.append(uid)
        is_female = i % 2 == 0
        name = rng.choice(NAMES_F if is_female else NAMES_M)
        gender = "female" if is_female else "male"
        age = rng.randint(20, 38)
        lat, lon = scatter(rng, i)
        photo = PHOTOS[i % len(PHOTOS)]
        extra = PHOTOS[(i + 3) % len(PHOTOS)]
        picked_interests = rng.sample(INTERESTS, k=rng.randint(3, 5))
        bio = rng.choice(
            [
                "Ищу интересные события в Кирове.",
                "Люблю активный отдых и новые знакомства.",
                "Часто хожу на концерты и выставки.",
                "Открыт(а) к новым встречам и мероприятиям.",
                "Живу в Кирове, люблю городские ивенты.",
            ]
        )

        user_rows.append(
            f"""(
  {sql_str(uid)},
  {sql_str(f'fake-match-sim-fb-{i:03d}')},
  {sql_str(f'fake-match-sim-sb-{i:03d}')},
  {sql_str(f'sim.user{i:03d}@kirov.test')},
  {sql_str(name)},
  {sql_str(photo)},
  {sql_array([extra])},
  {sql_str(bio)},
  {sql_array(picked_interests)},
  '{{}}'::jsonb,
  {age},
  {sql_str(gender)},
  'USER',
  {lat},
  {lon},
  NOW(),
  true,
  true,
  {max(18, age - 5)},
  {min(45, age + 8)},
  50000,
  NULL,
  true,
  true,
  NOW(),
  NOW()
)"""
        )

    event_rows: list[str] = []
    event_ids: list[str] = []
    participant_rows: list[str] = []

    for i in range(1, EVENT_COUNT + 1):
        eid = f"sim-event-{i:03d}"
        event_ids.append(eid)
        cat_slug, cat_label = CATEGORIES[i % len(CATEGORIES)]
        title = rng.choice(EVENT_TITLES[cat_slug])
        street = rng.choice(STREETS)
        location = f"Киров, {street}"
        lat, lon = scatter(rng, i + 100)
        creator = user_ids[i % len(user_ids)]
        days_ahead = rng.randint(1, 14)
        hours = rng.choice([2, 3, 4, 5])
        price = rng.choice([0, 0, 0, 300, 500, 800])
        image = EVENT_IMAGES[i % len(EVENT_IMAGES)]
        max_p = rng.choice([40, 60, 80, 100, 120, 200])
        desc = f"{cat_label} в Кирове. Приходите, будет интересно!"

        event_rows.append(
            f"""(
  {sql_str(eid)},
  {sql_str(title)},
  {sql_str(desc)},
  {sql_str(cat_slug)},
  {sql_str(location)},
  {lat},
  {lon},
  ST_SetSRID(ST_MakePoint({lon}, {lat}), 4326)::geography,
  NOW() + INTERVAL '{days_ahead} days',
  NOW() + INTERVAL '{days_ahead} days {hours} hours',
  {price},
  {sql_str(image)},
  false,
  'APPROVED',
  {max_p},
  {sql_str(creator)},
  NOW(),
  NOW()
)"""
        )

        going_count = rng.randint(6, min(14, len(user_ids)))
        going_users = rng.sample(user_ids, k=going_count)
        for j, uid in enumerate(going_users):
            pid = f"sim-part-{i:03d}-{j:02d}"
            participant_rows.append(
                f"({sql_str(pid)}, {sql_str(uid)}, {sql_str(eid)}, 'GOING', NOW(), NOW())"
            )

    sql = f"""-- Kirov city simulation: {USER_COUNT} users, {EVENT_COUNT} events.
-- Safe to re-run (upsert). Generated by scripts/generate_kirov_simulation.py

BEGIN;

CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS events;

ALTER TABLE IF EXISTS users."User"
  ADD COLUMN IF NOT EXISTS "photos" TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE IF EXISTS users."User"
  ADD COLUMN IF NOT EXISTS "firebaseUid" TEXT;
ALTER TABLE IF EXISTS users."User"
  ADD COLUMN IF NOT EXISTS "showInMatches" BOOLEAN NOT NULL DEFAULT true;

-- Re-scatter existing demo bots across Kirov.
UPDATE users."User"
SET
  "lastLatitude" = 58.555
    + ((get_byte(decode(md5(id), 'hex'), 0) % 90) / 1000.0),
  "lastLongitude" = 49.580
    + ((get_byte(decode(md5(id), 'hex'), 1) % 140) / 1000.0),
  "lastLocationUpdate" = NOW(),
  "isLocationVisible" = true,
  "showInMatches" = true
WHERE id LIKE 'fake-match-%';

INSERT INTO users."User" (
  "id",
  "firebaseUid",
  "supabaseUid",
  "email",
  "displayName",
  "photoUrl",
  "photos",
  "bio",
  "interests",
  "socialLinks",
  "age",
  "gender",
  "role",
  "lastLatitude",
  "lastLongitude",
  "lastLocationUpdate",
  "isProfileVisible",
  "isLocationVisible",
  "minAge",
  "maxAge",
  "maxDistance",
  "fcmToken",
  "isOnboardingCompleted",
  "showInMatches",
  "createdAt",
  "updatedAt"
)
VALUES
{",\n".join(user_rows)}
ON CONFLICT ("id") DO UPDATE SET
  "firebaseUid" = EXCLUDED."firebaseUid",
  "supabaseUid" = EXCLUDED."supabaseUid",
  "email" = EXCLUDED."email",
  "displayName" = EXCLUDED."displayName",
  "photoUrl" = EXCLUDED."photoUrl",
  "photos" = EXCLUDED."photos",
  "bio" = EXCLUDED."bio",
  "interests" = EXCLUDED."interests",
  "age" = EXCLUDED."age",
  "gender" = EXCLUDED."gender",
  "lastLatitude" = EXCLUDED."lastLatitude",
  "lastLongitude" = EXCLUDED."lastLongitude",
  "lastLocationUpdate" = EXCLUDED."lastLocationUpdate",
  "isProfileVisible" = EXCLUDED."isProfileVisible",
  "isLocationVisible" = EXCLUDED."isLocationVisible",
  "isOnboardingCompleted" = EXCLUDED."isOnboardingCompleted",
  "showInMatches" = EXCLUDED."showInMatches",
  "updatedAt" = NOW();

INSERT INTO events."Event" (
  "id",
  "title",
  "description",
  "category",
  "location",
  "latitude",
  "longitude",
  "locationGeo",
  "dateTime",
  "endDateTime",
  "price",
  "imageUrl",
  "isOnline",
  "status",
  "maxParticipants",
  "createdById",
  "createdAt",
  "updatedAt"
)
VALUES
{",\n".join(event_rows)}
ON CONFLICT ("id") DO UPDATE SET
  "title" = EXCLUDED."title",
  "description" = EXCLUDED."description",
  "category" = EXCLUDED."category",
  "location" = EXCLUDED."location",
  "latitude" = EXCLUDED."latitude",
  "longitude" = EXCLUDED."longitude",
  "locationGeo" = EXCLUDED."locationGeo",
  "dateTime" = EXCLUDED."dateTime",
  "endDateTime" = EXCLUDED."endDateTime",
  "price" = EXCLUDED."price",
  "imageUrl" = EXCLUDED."imageUrl",
  "status" = EXCLUDED."status",
  "updatedAt" = NOW();

INSERT INTO events."Participant" (
  "id",
  "userId",
  "eventId",
  "status",
  "joinedAt",
  "updatedAt"
)
VALUES
{",\n".join(participant_rows)}
ON CONFLICT ("id") DO UPDATE SET
  "status" = EXCLUDED."status",
  "updatedAt" = NOW();

COMMIT;

SELECT 'sim_users' AS kind, count(*)::text AS cnt
FROM users."User" WHERE id LIKE 'fake-match-sim-%'
UNION ALL
SELECT 'sim_events', count(*)::text FROM events."Event" WHERE id LIKE 'sim-event-%'
UNION ALL
SELECT 'sim_participants', count(*)::text FROM events."Participant" WHERE id LIKE 'sim-part-%'
UNION ALL
SELECT 'bots_on_map', count(*)::text
FROM users."User"
WHERE (id LIKE 'fake-match-%')
  AND "lastLatitude" IS NOT NULL;
"""

    OUT.write_text(sql, encoding="utf-8")
    print(f"Wrote {OUT} ({len(sql) // 1024} KB)")


if __name__ == "__main__":
    main()
