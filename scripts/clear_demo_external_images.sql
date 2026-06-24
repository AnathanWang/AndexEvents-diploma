-- Clear external CDN image URLs from demo events (phone may not reach Unsplash).
-- Safe to re-run.

BEGIN;

UPDATE events."Event"
SET "imageUrl" = '',
    "imageUrls" = ARRAY[]::text[],
    "updatedAt" = NOW()
WHERE "id" LIKE 'demo-event-%'
  AND (
    "imageUrl" LIKE 'https://images.unsplash.com/%'
    OR EXISTS (
      SELECT 1
      FROM unnest(COALESCE("imageUrls", ARRAY[]::text[])) AS u(url)
      WHERE url LIKE 'https://images.unsplash.com/%'
    )
  );

COMMIT;
