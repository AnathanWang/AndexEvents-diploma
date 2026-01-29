-- DANGER: This wipes ALL application data.
-- Review before running.
-- Usage example:
--   psql "postgresql://andexevents:andexevents_dev_password@localhost:5432/andexevents" -f scripts/wipe_db.sql

BEGIN;

TRUNCATE TABLE
  "Notification",
  "Match",
  "Participant",
  "Event",
  "FriendRequest",
  "Friendship",
  "User"
RESTART IDENTITY CASCADE;

COMMIT;
