-- Ensure Firebase UID and Supabase UID columns exist (shared DB safety)

ALTER TABLE IF EXISTS "User" ADD COLUMN IF NOT EXISTS "firebaseUid" TEXT;
ALTER TABLE IF EXISTS "User" ADD COLUMN IF NOT EXISTS "supabaseUid" TEXT;

-- Backfill whichever is missing
UPDATE "User"
SET "firebaseUid" = COALESCE("firebaseUid", "supabaseUid")
WHERE "firebaseUid" IS NULL AND "supabaseUid" IS NOT NULL;

UPDATE "User"
SET "supabaseUid" = COALESCE("supabaseUid", "firebaseUid")
WHERE "supabaseUid" IS NULL AND "firebaseUid" IS NOT NULL;

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS "User_firebaseUid_key" ON "User"("firebaseUid");
CREATE INDEX IF NOT EXISTS "User_firebaseUid_idx" ON "User"("firebaseUid");

CREATE UNIQUE INDEX IF NOT EXISTS "User_supabaseUid_key" ON "User"("supabaseUid");
CREATE INDEX IF NOT EXISTS "User_supabaseUid_idx" ON "User"("supabaseUid");
