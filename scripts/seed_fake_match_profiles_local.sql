-- Seed fake profiles near local coordinates used by current test account.
-- Target area: lat ~58.36, lon ~49.39 (within 50 km radius).
-- Safe to re-run: upsert by id.

BEGIN;

INSERT INTO users."User" (
  "id", "firebaseUid", "supabaseUid", "email", "displayName",
  "photoUrl", "photos", "bio", "interests", "socialLinks",
  "age", "gender", "role", "lastLatitude", "lastLongitude",
  "lastLocationUpdate", "isProfileVisible", "isLocationVisible",
  "minAge", "maxAge", "maxDistance", "fcmToken",
  "isOnboardingCompleted", "createdAt", "updatedAt"
)
VALUES
(
  'fake-match-local-alina', 'fake-firebase-local-alina', 'fake-supabase-local-alina',
  'alina.local.match@example.test', 'Alina',
  '/uploads/photos/seed/photo-1487412720507-e7ab37603c6f.jpg',
  ARRAY['/uploads/photos/seed/photo-1541101767792-f9b2b1c4f127.jpg']::TEXT[],
  'Йога, кофе и пешие прогулки по городу.',
  ARRAY['yoga','coffee','walking','books']::TEXT[],
  '{"telegram":"@alina_local"}'::jsonb,
  27, 'female', 'USER', 58.3612, 49.3921,
  NOW(), true, true, 21, 36, 50000, NULL,
  true, NOW(), NOW()
),
(
  'fake-match-local-misha', 'fake-firebase-local-misha', 'fake-supabase-local-misha',
  'misha.local.match@example.test', 'Misha',
  '/uploads/photos/seed/photo-1500648767791-00dcc994a43e.jpg',
  ARRAY['/uploads/photos/seed/photo-1463453091185-61582044d556.jpg']::TEXT[],
  'Люблю вело, стендап и ночные покатушки.',
  ARRAY['cycling','standup','music','travel']::TEXT[],
  '{"instagram":"misha_local"}'::jsonb,
  29, 'male', 'USER', 58.3538, 49.4014,
  NOW(), true, true, 22, 38, 50000, NULL,
  true, NOW(), NOW()
),
(
  'fake-match-local-sonya', 'fake-firebase-local-sonya', 'fake-supabase-local-sonya',
  'sonya.local.match@example.test', 'Sonya',
  '/uploads/photos/seed/photo-1529626455594-4ff0802cfb7e.jpg',
  ARRAY['/uploads/photos/seed/photo-1464863979621-258859e62245.jpg']::TEXT[],
  'Театр, выставки и спонтанные поездки выходного дня.',
  ARRAY['theatre','art','weekend-trips','cinema']::TEXT[],
  '{"telegram":"@sonya_local"}'::jsonb,
  26, 'female', 'USER', 58.3674, 49.3777,
  NOW(), true, true, 20, 35, 50000, NULL,
  true, NOW(), NOW()
),
(
  'fake-match-local-artem', 'fake-firebase-local-artem', 'fake-supabase-local-artem',
  'artem.local.match@example.test', 'Artem',
  '/uploads/photos/seed/photo-1506277886164-e25aa3f4ef7f.jpg',
  ARRAY['/uploads/photos/seed/photo-1547425260-76bcadfb4f2c.jpg']::TEXT[],
  'Футбол, продуктовые митапы и капучино утром.',
  ARRAY['football','product','coffee','networking']::TEXT[],
  '{"telegram":"@artem_local"}'::jsonb,
  31, 'male', 'USER', 58.3499, 49.4105,
  NOW(), true, true, 24, 42, 50000, NULL,
  true, NOW(), NOW()
),
(
  'fake-match-local-liza', 'fake-firebase-local-liza', 'fake-supabase-local-liza',
  'liza.local.match@example.test', 'Liza',
  '/uploads/photos/seed/photo-1438761681033-6461ffad8d80.jpg',
  ARRAY['/uploads/photos/seed/photo-1489424731084-a5d8b219a5bb.jpg']::TEXT[],
  'Плавание, пилатес и уютные кофейни.',
  ARRAY['swimming','pilates','coffee','wellness']::TEXT[],
  '{"instagram":"liza_local"}'::jsonb,
  30, 'female', 'USER', 58.3723, 49.3864,
  NOW(), true, true, 23, 40, 50000, NULL,
  true, NOW(), NOW()
),
(
  'fake-match-local-egor', 'fake-firebase-local-egor', 'fake-supabase-local-egor',
  'egor.local.match@example.test', 'Egor',
  '/uploads/photos/seed/photo-1506794778202-cad84cf45f1d.jpg',
  ARRAY['/uploads/photos/seed/photo-1504593811423-6dd665756598.jpg']::TEXT[],
  'Бег, настолки и IT-конференции.',
  ARRAY['running','boardgames','it','movies']::TEXT[],
  '{"telegram":"@egor_local"}'::jsonb,
  28, 'male', 'USER', 58.3588, 49.3959,
  NOW(), true, true, 22, 37, 50000, NULL,
  true, NOW(), NOW()
)
ON CONFLICT (id) DO UPDATE SET
  "firebaseUid" = EXCLUDED."firebaseUid",
  "supabaseUid" = EXCLUDED."supabaseUid",
  "email" = EXCLUDED."email",
  "displayName" = EXCLUDED."displayName",
  "photoUrl" = EXCLUDED."photoUrl",
  "photos" = EXCLUDED."photos",
  "bio" = EXCLUDED."bio",
  "interests" = EXCLUDED."interests",
  "socialLinks" = EXCLUDED."socialLinks",
  "age" = EXCLUDED."age",
  "gender" = EXCLUDED."gender",
  "role" = EXCLUDED."role",
  "lastLatitude" = EXCLUDED."lastLatitude",
  "lastLongitude" = EXCLUDED."lastLongitude",
  "lastLocationUpdate" = EXCLUDED."lastLocationUpdate",
  "isProfileVisible" = EXCLUDED."isProfileVisible",
  "isLocationVisible" = EXCLUDED."isLocationVisible",
  "minAge" = EXCLUDED."minAge",
  "maxAge" = EXCLUDED."maxAge",
  "maxDistance" = EXCLUDED."maxDistance",
  "fcmToken" = EXCLUDED."fcmToken",
  "isOnboardingCompleted" = EXCLUDED."isOnboardingCompleted",
  "updatedAt" = NOW();

COMMIT;

SELECT id, "displayName", "lastLatitude", "lastLongitude"
FROM users."User"
WHERE id LIKE 'fake-match-local-%'
ORDER BY "displayName";
