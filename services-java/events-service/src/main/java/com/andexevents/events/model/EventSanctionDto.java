package com.andexevents.events.model;

import java.time.Instant;

public record EventSanctionDto(
        String id,
        String eventId,
        EventSanctionType type,
        String reason,
        String createdById,
        Instant expiresAt,
        Instant revokedAt,
        String revokedById,
        Instant createdAt,
        Instant updatedAt
) {
    public boolean isActive() {
        return revokedAt == null && (expiresAt == null || expiresAt.isAfter(Instant.now()));
    }
}

