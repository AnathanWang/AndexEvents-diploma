ALTER TABLE users."User"
    ADD COLUMN IF NOT EXISTS "coverImageUrl" TEXT;

CREATE TABLE IF NOT EXISTS users."UserBlock" (
    id TEXT PRIMARY KEY,
    "blockerId" TEXT NOT NULL,
    "targetUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_block_unique_pair UNIQUE ("blockerId", "targetUserId"),
    CONSTRAINT user_block_not_self CHECK ("blockerId" <> "targetUserId"),
    CONSTRAINT user_block_blocker_fk FOREIGN KEY ("blockerId") REFERENCES users."User"(id) ON DELETE CASCADE,
    CONSTRAINT user_block_target_fk FOREIGN KEY ("targetUserId") REFERENCES users."User"(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_block_blocker ON users."UserBlock" ("blockerId");
CREATE INDEX IF NOT EXISTS idx_user_block_target ON users."UserBlock" ("targetUserId");
