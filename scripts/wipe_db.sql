-- DANGER: This wipes application data (users/events/etc).
-- Safe for hybrid stacks: it truncates ONLY tables that exist.
-- Usage example:
--   psql "postgresql://andexevents:andexevents_dev_password@localhost:5432/andexevents" -f scripts/wipe_db.sql

DO $$
DECLARE
  tables text[] := ARRAY[
    'public."Notification"',
    'public."Match"',
    'public."Participant"',
    'public."Event"',
    'public."FriendRequest"',
    'public."Friendship"',
    'public."User"'
  ];
  t text;
  existing text := '';
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF to_regclass(t) IS NOT NULL THEN
      existing := existing || CASE WHEN existing = '' THEN '' ELSE ', ' END || t;
    END IF;
  END LOOP;

  IF existing <> '' THEN
    EXECUTE 'TRUNCATE TABLE ' || existing || ' RESTART IDENTITY CASCADE';
  END IF;
END $$;
