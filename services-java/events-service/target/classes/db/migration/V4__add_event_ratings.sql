-- V4: Add EventRating table for event rating system

CREATE TABLE IF NOT EXISTS events."EventRating" (
  "id"        TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "eventId"   TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
  "userId"    TEXT NOT NULL,
  "rating"    SMALLINT NOT NULL CHECK ("rating" BETWEEN 1 AND 5),
  "comment"   TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE ("userId", "eventId")
);

CREATE INDEX IF NOT EXISTS "EventRating_eventId_idx" ON events."EventRating"("eventId");
CREATE INDEX IF NOT EXISTS "EventRating_userId_idx"  ON events."EventRating"("userId");
