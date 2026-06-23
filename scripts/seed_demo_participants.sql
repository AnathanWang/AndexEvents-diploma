-- Seed demo GOING participants so event-level matches have profiles to swipe.
-- Safe to re-run: upsert by id.

BEGIN;

INSERT INTO events."Participant" (
  "id",
  "userId",
  "eventId",
  "status",
  "joinedAt",
  "updatedAt"
)
VALUES
  ('demo-part-jazz-igor', 'fake-match-igor', 'demo-event-kirov-jazz', 'GOING', NOW(), NOW()),
  ('demo-part-jazz-lena', 'fake-match-lena', 'demo-event-kirov-jazz', 'GOING', NOW(), NOW()),
  ('demo-part-jazz-max', 'fake-match-max', 'demo-event-kirov-jazz', 'GOING', NOW(), NOW()),
  ('demo-part-jazz-polina', 'fake-match-polina', 'demo-event-kirov-jazz', 'GOING', NOW(), NOW()),

  ('demo-part-run-anna', 'fake-match-anna', 'demo-event-kirov-run', 'GOING', NOW(), NOW()),
  ('demo-part-run-lena', 'fake-match-lena', 'demo-event-kirov-run', 'GOING', NOW(), NOW()),
  ('demo-part-run-nikita', 'fake-match-nikita', 'demo-event-kirov-run', 'GOING', NOW(), NOW()),
  ('demo-part-run-vera', 'fake-match-vera', 'demo-event-kirov-run', 'GOING', NOW(), NOW()),

  ('demo-part-art-igor', 'fake-match-igor', 'demo-event-kirov-art', 'GOING', NOW(), NOW()),
  ('demo-part-art-olga', 'fake-match-olga', 'demo-event-kirov-art', 'GOING', NOW(), NOW()),
  ('demo-part-art-kate', 'fake-match-kate', 'demo-event-kirov-art', 'GOING', NOW(), NOW()),
  ('demo-part-art-maria', 'fake-match-maria', 'demo-event-kirov-art', 'GOING', NOW(), NOW()),

  ('demo-part-tech-anna', 'fake-match-anna', 'demo-event-kirov-tech', 'GOING', NOW(), NOW()),
  ('demo-part-tech-max', 'fake-match-max', 'demo-event-kirov-tech', 'GOING', NOW(), NOW()),
  ('demo-part-tech-daniil', 'fake-match-daniil', 'demo-event-kirov-tech', 'GOING', NOW(), NOW()),
  ('demo-part-tech-timur', 'fake-match-timur', 'demo-event-kirov-tech', 'GOING', NOW(), NOW()),

  ('demo-part-party-igor', 'fake-match-igor', 'demo-event-kirov-party', 'GOING', NOW(), NOW()),
  ('demo-part-party-kate', 'fake-match-kate', 'demo-event-kirov-party', 'GOING', NOW(), NOW()),
  ('demo-part-party-roman', 'fake-match-roman', 'demo-event-kirov-party', 'GOING', NOW(), NOW()),
  ('demo-part-party-julia', 'fake-match-julia', 'demo-event-kirov-party', 'GOING', NOW(), NOW())
ON CONFLICT ("id") DO UPDATE SET
  "status" = EXCLUDED."status",
  "updatedAt" = NOW();

COMMIT;

SELECT p."eventId", count(*) AS going_count
FROM events."Participant" p
WHERE p."status" = 'GOING'
  AND p."eventId" LIKE 'demo-event-kirov-%'
GROUP BY p."eventId"
ORDER BY p."eventId";
