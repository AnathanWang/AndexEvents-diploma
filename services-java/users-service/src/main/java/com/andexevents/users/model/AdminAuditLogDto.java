package com.andexevents.users.model;

import java.time.Instant;
import java.util.Map;

public record AdminAuditLogDto(
        String id,
        String actorUserId,
        String targetUserId,
        String action,
        Map<String, Object> details,
        Instant createdAt
) {
}
