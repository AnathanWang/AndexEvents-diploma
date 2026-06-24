-- Refresh fake bots for map (lastLocationUpdate < 3 min) and event matches.
-- Anchor: Cenya4 / Ремонт ботов area (~58.589, 49.598), Kirov.

BEGIN;

UPDATE users."User" SET
  "lastLatitude" = v.lat,
  "lastLongitude" = v.lon,
  "lastLocationUpdate" = NOW(),
  "isProfileVisible" = true,
  "isLocationVisible" = true,
  "showInMatches" = true,
  "isOnboardingCompleted" = true,
  "updatedAt" = NOW()
FROM (VALUES
  ('fake-match-anna',     58.5878::float8, 49.5962::float8),
  ('fake-match-igor',     58.5905, 49.6010),
  ('fake-match-lena',     58.5912, 49.5945),
  ('fake-match-max',      58.5865, 49.5998),
  ('fake-match-olga',     58.5928, 49.5920),
  ('fake-match-daniil',   58.5889, 49.6035),
  ('fake-match-kate',     58.5935, 49.5975),
  ('fake-match-roman',    58.5855, 49.5950),
  ('fake-match-polina',   58.5900, 49.5905),
  ('fake-match-nikita',   58.5870, 49.6020),
  ('fake-match-vera',     58.5920, 49.6005),
  ('fake-match-timur',    58.5895, 49.6055),
  ('fake-match-maria',    58.5860, 49.5925),
  ('fake-match-alex',     58.5918, 49.6060),
  ('fake-match-julia',    58.5942, 49.5938),
  ('fake-match-denis',    58.5880, 49.5890),
  ('fake-match-local-alina',  58.5908, 49.5970),
  ('fake-match-local-misha',  58.5875, 49.6000),
  ('fake-match-local-sonya',  58.5930, 49.5990),
  ('fake-match-local-artem',  58.5868, 49.6040),
  ('fake-match-local-liza',   58.5925, 49.5955),
  ('fake-match-local-egor',   58.5890, 49.5910)
) AS v(id, lat, lon)
WHERE users."User".id = v.id;

-- Extra bots near the same area (new profiles).
INSERT INTO users."User" (
  "id", "firebaseUid", "supabaseUid", "email", "displayName",
  "photoUrl", "photos", "bio", "interests", "socialLinks",
  "age", "gender", "role", "lastLatitude", "lastLongitude",
  "lastLocationUpdate", "isProfileVisible", "isLocationVisible",
  "showInMatches", "minAge", "maxAge", "maxDistance",
  "isOnboardingCompleted", "createdAt", "updatedAt"
)
VALUES
(
  'fake-match-sveta', 'fake-firebase-sveta', 'fake-supabase-sveta',
  'sveta.match@example.test', 'Sveta',
  '/uploads/photos/seed/photo-1517841905240-472988babdf9.jpg',
  ARRAY['/uploads/photos/seed/photo-1524504388940-b1c1722653e1.jpg']::TEXT[],
  'Люблю прогулки, кофе и живую музыку.',
  ARRAY['coffee','music','walking','art']::TEXT[],
  '{"telegram":"@sveta_k"}'::jsonb,
  27, 'female', 'USER', 58.5910, 49.5988,
  NOW(), true, true, true, 21, 35, 50000, true, NOW(), NOW()
),
(
  'fake-match-pavel', 'fake-firebase-pavel', 'fake-supabase-pavel',
  'pavel.match@example.test', 'Pavel',
  '/uploads/photos/seed/photo-1507003211169-0a1dd7228f2d.jpg',
  ARRAY['/uploads/photos/seed/photo-1463453091185-61582044d556.jpg']::TEXT[],
  'Бег, митапы и крафтовое пиво.',
  ARRAY['running','beer','tech','networking']::TEXT[],
  '{"telegram":"@pavel_run"}'::jsonb,
  29, 'male', 'USER', 58.5885, 49.6015,
  NOW(), true, true, true, 22, 38, 50000, true, NOW(), NOW()
),
(
  'fake-match-kira', 'fake-firebase-kira', 'fake-supabase-kira',
  'kira.match@example.test', 'Kira',
  '/uploads/photos/seed/photo-1534528741775-53994a69daeb.jpg',
  ARRAY['/uploads/photos/seed/photo-1489424731084-a5d8b219a5bb.jpg']::TEXT[],
  'Дизайн, выставки и винтажные рынки.',
  ARRAY['design','art','vintage','cinema']::TEXT[],
  '{"instagram":"kira_art"}'::jsonb,
  25, 'female', 'USER', 58.5858, 49.5972,
  NOW(), true, true, true, 20, 33, 50000, true, NOW(), NOW()
),
(
  'fake-match-oleg', 'fake-firebase-oleg', 'fake-supabase-oleg',
  'oleg.match@example.test', 'Oleg',
  '/uploads/photos/seed/photo-1539571696357-5a69c17a67c6.jpg',
  ARRAY['/uploads/photos/seed/photo-1547425260-76bcadfb4f2c.jpg']::TEXT[],
  'Backend, настолки и походы.',
  ARRAY['backend','boardgames','hiking','coffee']::TEXT[],
  '{"telegram":"@oleg_dev"}'::jsonb,
  30, 'male', 'USER', 58.5938, 49.6025,
  NOW(), true, true, true, 24, 40, 50000, true, NOW(), NOW()
),
(
  'fake-match-nastya', 'fake-firebase-nastya', 'fake-supabase-nastya',
  'nastya.match@example.test', 'Nastya',
  '/uploads/photos/seed/photo-1544005313-94ddf0286df2.jpg',
  ARRAY['/uploads/photos/seed/photo-1512290923902-8a9f81dc236c.jpg']::TEXT[],
  'Йога, книги и уютные вечера.',
  ARRAY['yoga','books','wellness','tea']::TEXT[],
  '{"telegram":"@nastya_calm"}'::jsonb,
  26, 'female', 'USER', 58.5902, 49.5935,
  NOW(), true, true, true, 21, 34, 50000, true, NOW(), NOW()
),
(
  'fake-match-kirill', 'fake-firebase-kirill', 'fake-supabase-kirill',
  'kirill.match@example.test', 'Kirill',
  '/uploads/photos/seed/photo-1504257432389-52343af06ae3.jpg',
  ARRAY['/uploads/photos/seed/photo-1521119989659-a83eee488004.jpg']::TEXT[],
  'Футбол, барбекю и стартапы.',
  ARRAY['football','bbq','startups','travel']::TEXT[],
  '{"telegram":"@kirill_pm"}'::jsonb,
  28, 'male', 'USER', 58.5862, 49.6008,
  NOW(), true, true, true, 22, 36, 50000, true, NOW(), NOW()
)
ON CONFLICT (id) DO UPDATE SET
  "lastLatitude" = EXCLUDED."lastLatitude",
  "lastLongitude" = EXCLUDED."lastLongitude",
  "lastLocationUpdate" = NOW(),
  "isProfileVisible" = true,
  "isLocationVisible" = true,
  "showInMatches" = true,
  "isOnboardingCompleted" = true,
  "updatedAt" = NOW();

-- GOING participants on «Ремонт ботов» for event-level matches.
INSERT INTO events."Participant" (
  "id", "userId", "eventId", "status", "joinedAt", "updatedAt"
)
SELECT
  'demo-part-remont-' || replace(u.id, 'fake-match-', ''),
  u.id,
  '235407e2-17a9-4e74-a88a-b393348391a4',
  'GOING',
  NOW(),
  NOW()
FROM users."User" u
WHERE u.id LIKE 'fake-match-%'
  AND u.id NOT IN ('fake-match-anna', 'fake-match-max')
  AND NOT EXISTS (
    SELECT 1 FROM events."EventParticipantBan" b
    WHERE b."eventId" = '235407e2-17a9-4e74-a88a-b393348391a4'
      AND b."userId" = u.id
  )
ON CONFLICT ("userId", "eventId") DO UPDATE SET
  "status" = 'GOING',
  "updatedAt" = NOW();

COMMIT;

SELECT count(*) AS map_ready_bots
FROM users."User" u
WHERE u.id LIKE 'fake-match-%'
  AND u."isLocationVisible" = true
  AND u."lastLocationUpdate" > NOW() - INTERVAL '3 minutes';

SELECT count(*) AS remont_going_bots
FROM events."Participant" p
WHERE p."eventId" = '235407e2-17a9-4e74-a88a-b393348391a4'
  AND p.status = 'GOING'
  AND p."userId" LIKE 'fake-match-%';
