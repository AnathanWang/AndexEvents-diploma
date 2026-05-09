CREATE SCHEMA IF NOT EXISTS events;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'EventStatus' AND typnamespace = 'events'::regnamespace) THEN
        CREATE TYPE events."EventStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS events."Event" (
    "id" TEXT PRIMARY KEY,
    "createdById" TEXT,
    "status" events."EventStatus" NOT NULL DEFAULT 'PENDING'
);

CREATE TABLE IF NOT EXISTS events."EventRating" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "eventId" TEXT NOT NULL REFERENCES events."Event"(id) ON DELETE CASCADE,
    "userId" TEXT NOT NULL,
    "rating" SMALLINT NOT NULL CHECK ("rating" BETWEEN 1 AND 5),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE ("userId", "eventId")
);

-- Match table is usually in public or users schema, but UserRepository refers to it as "Match"
-- In users-service tests, the default schema is "users", so we create it there.
CREATE TABLE IF NOT EXISTS "Match" (
    "id" TEXT PRIMARY KEY,
    "userAId" TEXT NOT NULL,
    "userBId" TEXT NOT NULL,
    "eventId" TEXT,
    "userAAction" TEXT,
    "userBAction" TEXT,
    "isMutual" BOOLEAN DEFAULT false,
    "matchedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
