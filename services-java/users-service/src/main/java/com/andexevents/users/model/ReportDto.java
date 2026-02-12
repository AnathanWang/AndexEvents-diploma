package com.andexevents.users.model;

import java.time.Instant;

public record ReportDto(
    String id,
    String reporterId,
    String targetUserId,
    String targetEventId,
    ReportReason reason,
    String details,
    ReportStatus status,
    String resolverId,
    Instant resolvedAt,
    Instant createdAt,
    Instant updatedAt
) {
}
