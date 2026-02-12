-- Minimal schema for users-service (shared DB). Uses IF NOT EXISTS to be safe.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE "UserRole" AS ENUM ('USER', 'MODERATOR', 'ADMIN');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS "User" (
  "id" TEXT PRIMARY KEY,
  "supabaseUid" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "displayName" TEXT,
  "photoUrl" TEXT,
  "bio" TEXT,
  "interests" TEXT[] DEFAULT ARRAY[]::TEXT[],
  "socialLinks" JSONB,
  "age" INTEGER,
  "gender" TEXT,
  "role" "UserRole" NOT NULL DEFAULT 'USER',
  "lastLatitude" DOUBLE PRECISION,
  "lastLongitude" DOUBLE PRECISION,
  "lastLocationUpdate" TIMESTAMP(3),
  "isProfileVisible" BOOLEAN NOT NULL DEFAULT true,
  "isLocationVisible" BOOLEAN NOT NULL DEFAULT true,
  "minAge" INTEGER,
  "maxAge" INTEGER,
  "maxDistance" INTEGER NOT NULL DEFAULT 50000,
  "fcmToken" TEXT,
  "isOnboardingCompleted" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "User_supabaseUid_key" ON "User"("supabaseUid");
CREATE UNIQUE INDEX IF NOT EXISTS "User_email_key" ON "User"("email");
CREATE INDEX IF NOT EXISTS "User_supabaseUid_idx" ON "User"("supabaseUid");
CREATE INDEX IF NOT EXISTS "User_email_idx" ON "User"("email");
