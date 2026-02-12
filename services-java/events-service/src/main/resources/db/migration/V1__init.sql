-- Minimal schema for events-service (shared DB). Uses IF NOT EXISTS to be safe.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE "EventStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE "ParticipantStatus" AS ENUM ('INTERESTED', 'GOING');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS "Event" (
  "id" TEXT PRIMARY KEY,
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "location" TEXT NOT NULL,
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "locationGeo" geography(Point, 4326),
  "dateTime" TIMESTAMP(3) NOT NULL,
  "endDateTime" TIMESTAMP(3),
  "price" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "imageUrl" TEXT,
  "isOnline" BOOLEAN NOT NULL DEFAULT false,
  "status" "EventStatus" NOT NULL DEFAULT 'PENDING',
  "rejectionReason" TEXT,
  "maxParticipants" INTEGER,
  "minAge" INTEGER,
  "maxAge" INTEGER,
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "Event_createdById_idx" ON "Event"("createdById");
CREATE INDEX IF NOT EXISTS "Event_status_idx" ON "Event"("status");
CREATE INDEX IF NOT EXISTS "Event_dateTime_idx" ON "Event"("dateTime");
CREATE INDEX IF NOT EXISTS "Event_category_idx" ON "Event"("category");

CREATE TABLE IF NOT EXISTS "Participant" (
  "id" TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "eventId" TEXT NOT NULL,
  "status" "ParticipantStatus" NOT NULL DEFAULT 'INTERESTED',
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "Participant_userId_eventId_key" ON "Participant"("userId", "eventId");
CREATE INDEX IF NOT EXISTS "Participant_userId_idx" ON "Participant"("userId");
CREATE INDEX IF NOT EXISTS "Participant_eventId_idx" ON "Participant"("eventId");
