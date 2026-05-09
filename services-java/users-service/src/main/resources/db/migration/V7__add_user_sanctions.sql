DO $$ BEGIN
  CREATE TYPE "UserSanctionType" AS ENUM (
    'WARNING',
    'MUTE',
    'EVENT_CREATE_BAN',
    'FULL_BAN'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS "UserSanction" (
    "id" TEXT PRIMARY KEY,
    "targetUserId" TEXT NOT NULL REFERENCES "User"("id"),
    "createdByUserId" TEXT NOT NULL REFERENCES "User"("id"),
    "type" "UserSanctionType" NOT NULL,
    "reason" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "revokedByUserId" TEXT REFERENCES "User"("id"),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "UserSanction_targetUserId_idx" ON "UserSanction"("targetUserId");
CREATE INDEX IF NOT EXISTS "UserSanction_createdByUserId_idx" ON "UserSanction"("createdByUserId");
CREATE INDEX IF NOT EXISTS "UserSanction_createdAt_idx" ON "UserSanction"("createdAt" DESC);
CREATE INDEX IF NOT EXISTS "UserSanction_active_idx" ON "UserSanction"("targetUserId", "revokedAt", "expiresAt");
