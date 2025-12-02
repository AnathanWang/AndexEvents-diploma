-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "locationGeo" geography(Point, 4326);

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "socialLinks" JSONB;
