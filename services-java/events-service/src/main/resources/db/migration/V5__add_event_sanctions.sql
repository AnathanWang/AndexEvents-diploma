-- V5: Add EventSanction table and enum types

DO $$ BEGIN
  CREATE TYPE events."EventSanctionType" AS ENUM (
    'HIDE_VISIBILITY',
    'FREEZE_PARTICIPATION',
    'LIMIT_EDITS'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS events."EventSanction" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "eventId" TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
  "type" events."EventSanctionType" NOT NULL,
  "reason" TEXT NOT NULL,
  "createdById" TEXT,
  "expiresAt" TIMESTAMP(3),
  "revokedAt" TIMESTAMP(3),
  "revokedById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "EventSanction_eventId_type_active_idx"
  ON events."EventSanction"("eventId", "type", "revokedAt");

