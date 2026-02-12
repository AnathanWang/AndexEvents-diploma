-- Ensure Firebase UID and Supabase UID columns exist (shared DB safety)

ALTER TABLE IF EXISTS "User" ADD COLUMN IF NOT EXISTS "firebaseUid" TEXT;
ALTER TABLE IF EXISTS "User" ADD COLUMN IF NOT EXISTS "supabaseUid" TEXT;

DO $$
BEGIN
	-- In some environments (e.g. isolated events-service tests), the shared "User" table may not exist.
	IF to_regclass('public."User"') IS NOT NULL THEN
		-- Backfill whichever is missing
		EXECUTE 'UPDATE "User" SET "firebaseUid" = COALESCE("firebaseUid", "supabaseUid") WHERE "firebaseUid" IS NULL AND "supabaseUid" IS NOT NULL';
		EXECUTE 'UPDATE "User" SET "supabaseUid" = COALESCE("supabaseUid", "firebaseUid") WHERE "supabaseUid" IS NULL AND "firebaseUid" IS NOT NULL';

		-- Indexes
		EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "User_firebaseUid_key" ON "User"("firebaseUid")';
		EXECUTE 'CREATE INDEX IF NOT EXISTS "User_firebaseUid_idx" ON "User"("firebaseUid")';
		EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "User_supabaseUid_key" ON "User"("supabaseUid")';
		EXECUTE 'CREATE INDEX IF NOT EXISTS "User_supabaseUid_idx" ON "User"("supabaseUid")';
	END IF;
END $$;
