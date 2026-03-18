-- Add photos array column to User table for additional profile photos
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "photos" TEXT[] DEFAULT ARRAY[]::TEXT[];
