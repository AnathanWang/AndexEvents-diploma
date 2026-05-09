package com.andexevents.users.model;

import java.time.Instant;

public record UserSanctionDto(
        String id,
        String targetUserId,
        String createdByUserId,
        String type,
        String reason,
        Instant expiresAt,
        Instant revokedAt,
        String revokedByUserId,
        Instant createdAt,
        Instant updatedAt
) {
    public boolean active() {
        boolean notRevoked = revokedAt == null;
        boolean notExpired = expiresAt == null || expiresAt.isAfter(Instant.now());
        return notRevoked && notExpired;
    }
}
