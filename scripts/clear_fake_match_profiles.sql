-- Remove fake match profiles created for testing.
-- Safe to re-run.

BEGIN;

DELETE FROM users."User"
WHERE id LIKE 'fake-match-%';

COMMIT;

SELECT COUNT(*) AS fake_profiles_left
FROM users."User"
WHERE id LIKE 'fake-match-%';
