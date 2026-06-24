-- Point demo events at MinIO-hosted seed images.
BEGIN;

UPDATE events."Event" SET "imageUrl" = '/uploads/events/seed/demo-jazz-party.jpg', "updatedAt" = NOW()
WHERE "id" = 'demo-event-kirov-jazz';
UPDATE events."Event" SET "imageUrl" = '/uploads/events/seed/demo-run.jpg', "updatedAt" = NOW()
WHERE "id" = 'demo-event-kirov-run';
UPDATE events."Event" SET "imageUrl" = '/uploads/events/seed/demo-art.jpg', "updatedAt" = NOW()
WHERE "id" = 'demo-event-kirov-art';
UPDATE events."Event" SET "imageUrl" = '/uploads/events/seed/demo-tech.jpg', "updatedAt" = NOW()
WHERE "id" = 'demo-event-kirov-tech';
UPDATE events."Event" SET "imageUrl" = '/uploads/events/seed/demo-jazz-party.jpg', "updatedAt" = NOW()
WHERE "id" = 'demo-event-kirov-party';

COMMIT;
