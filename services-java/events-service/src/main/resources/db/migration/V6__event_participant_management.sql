-- V6: Event participant management (bans, organizer blocklist, waitlist, check-in)

DO $$ BEGIN
  CREATE TYPE events."WaitlistStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS events."EventParticipantBan" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "eventId" TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
  "userId" TEXT NOT NULL,
  "reason" TEXT,
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "EventParticipantBan_eventId_userId_key"
  ON events."EventParticipantBan"("eventId", "userId");

CREATE TABLE IF NOT EXISTS events."OrganizerBlock" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "organizerUserId" TEXT NOT NULL,
  "blockedUserId" TEXT NOT NULL,
  "reason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "OrganizerBlock_organizer_blocked_key"
  ON events."OrganizerBlock"("organizerUserId", "blockedUserId");

CREATE TABLE IF NOT EXISTS events."WaitlistEntry" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "eventId" TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
  "userId" TEXT NOT NULL,
  "status" events."WaitlistStatus" NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "WaitlistEntry_eventId_userId_key"
  ON events."WaitlistEntry"("eventId", "userId");

CREATE INDEX IF NOT EXISTS "WaitlistEntry_eventId_status_idx"
  ON events."WaitlistEntry"("eventId", "status");

CREATE TABLE IF NOT EXISTS events."ParticipantCheckIn" (
  "eventId" TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
  "userId" TEXT NOT NULL,
  "checkedIn" BOOLEAN NOT NULL DEFAULT false,
  "checkedInAt" TIMESTAMP(3),
  "checkedInById" TEXT,
  PRIMARY KEY ("eventId", "userId")
);

