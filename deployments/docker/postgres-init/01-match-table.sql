-- Create Match table for match-service
-- This table stores mutual matches and like/dislike actions between users

-- Create MatchAction enum type
DO $$ BEGIN
  CREATE TYPE "MatchAction" AS ENUM ('LIKE', 'DISLIKE', 'SUPER_LIKE');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create Match table in public schema
CREATE TABLE IF NOT EXISTS "Match" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "userAId" TEXT NOT NULL REFERENCES users."User"("id") ON DELETE CASCADE,
  "userBId" TEXT NOT NULL REFERENCES users."User"("id") ON DELETE CASCADE,
  "userAAction" "MatchAction",
  "userBAction" "MatchAction",
  "isMutual" BOOLEAN NOT NULL DEFAULT false,
  "matchedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Match_unique_pair" UNIQUE ("userAId", "userBId"),
  CONSTRAINT "Match_no_self_match" CHECK ("userAId" != "userBId")
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS "Match_userAId_idx" ON "Match"("userAId");
CREATE INDEX IF NOT EXISTS "Match_userBId_idx" ON "Match"("userBId");
CREATE INDEX IF NOT EXISTS "Match_isMutual_idx" ON "Match"("isMutual");
CREATE INDEX IF NOT EXISTS "Match_matchedAt_idx" ON "Match"("matchedAt");

-- Create index for querying matches for a specific user
CREATE INDEX IF NOT EXISTS "Match_user_lookup_idx" ON "Match"("userAId", "userBId", "isMutual");
