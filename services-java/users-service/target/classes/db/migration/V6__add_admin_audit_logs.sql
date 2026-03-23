CREATE TABLE IF NOT EXISTS "AdminAuditLog" (
    "id" TEXT PRIMARY KEY,
    "actorUserId" TEXT NOT NULL REFERENCES "User"("id"),
    "targetUserId" TEXT REFERENCES "User"("id"),
    "action" TEXT NOT NULL,
    "details" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "AdminAuditLog_actorUserId_idx" ON "AdminAuditLog"("actorUserId");
CREATE INDEX IF NOT EXISTS "AdminAuditLog_targetUserId_idx" ON "AdminAuditLog"("targetUserId");
CREATE INDEX IF NOT EXISTS "AdminAuditLog_createdAt_idx" ON "AdminAuditLog"("createdAt" DESC);
