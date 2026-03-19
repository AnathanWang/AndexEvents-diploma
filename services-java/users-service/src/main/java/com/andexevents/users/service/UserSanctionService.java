package com.andexevents.users.service;

import com.andexevents.users.model.UserSanctionDto;
import com.andexevents.users.repo.UserRepository;
import com.andexevents.users.repo.UserSanctionRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Locale;

@Service
public class UserSanctionService {
    private final UserSanctionRepository userSanctionRepository;
    private final UserRepository userRepository;

    public UserSanctionService(UserSanctionRepository userSanctionRepository, UserRepository userRepository) {
        this.userSanctionRepository = userSanctionRepository;
        this.userRepository = userRepository;
    }

    public UserSanctionDto createSanction(
            String targetUserId,
            String createdByUserId,
            String type,
            String reason,
            Instant expiresAt
    ) {
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new BadRequestException("targetUserId is required");
        }

        if (createdByUserId == null || createdByUserId.isBlank()) {
            throw new BadRequestException("createdByUserId is required");
        }

        if (reason == null || reason.trim().isEmpty()) {
            throw new BadRequestException("reason is required");
        }

        if (targetUserId.equals(createdByUserId)) {
            throw new BadRequestException("Cannot sanction yourself");
        }

        if (userRepository.findById(targetUserId).isEmpty()) {
            throw new NotFoundException("Target user not found");
        }

        if (userRepository.findById(createdByUserId).isEmpty()) {
            throw new NotFoundException("Actor user not found");
        }

        String normalizedType = normalizeType(type);
        if (expiresAt != null && !expiresAt.isAfter(Instant.now())) {
            throw new BadRequestException("expiresAt must be in the future");
        }

        return userSanctionRepository.insert(
                targetUserId,
                createdByUserId,
                normalizedType,
                reason.trim(),
                expiresAt
        );
    }

    public List<UserSanctionDto> getByTargetUser(String targetUserId) {
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new BadRequestException("targetUserId is required");
        }

        return userSanctionRepository.findByTargetUserId(targetUserId);
    }

    public UserSanctionDto getById(String sanctionId) {
        if (sanctionId == null || sanctionId.isBlank()) {
            throw new BadRequestException("sanctionId is required");
        }

        return userSanctionRepository.findById(sanctionId)
                .orElseThrow(() -> new NotFoundException("Sanction not found"));
    }

    public List<UserSanctionDto> getActiveAll(int limit) {
        return userSanctionRepository.findActiveAll(limit);
    }

    public void revoke(String sanctionId, String revokedByUserId) {
        if (sanctionId == null || sanctionId.isBlank()) {
            throw new BadRequestException("sanctionId is required");
        }

        if (revokedByUserId == null || revokedByUserId.isBlank()) {
            throw new BadRequestException("revokedByUserId is required");
        }

        UserSanctionDto sanction = userSanctionRepository.findById(sanctionId)
                .orElseThrow(() -> new NotFoundException("Sanction not found"));

        if (sanction.revokedAt() != null) {
            throw new BadRequestException("Sanction is already revoked");
        }

        userSanctionRepository.revoke(sanctionId, revokedByUserId);
    }

    public void assertCanSubmitReport(String userId) {
        boolean blocked = userSanctionRepository.hasActiveSanction(userId, "FULL_BAN", "MUTE");
        if (blocked) {
            throw new ForbiddenException("Your account is restricted from submitting reports");
        }
    }

    public void assertCanCreateEvent(String userId) {
        boolean blocked = userSanctionRepository.hasActiveSanction(userId, "FULL_BAN", "EVENT_CREATE_BAN");
        if (blocked) {
            throw new ForbiddenException("Your account is restricted from creating events");
        }
    }

    private String normalizeType(String type) {
        if (type == null) {
            throw new BadRequestException("type is required");
        }

        String normalized = type.trim().toUpperCase(Locale.ROOT);
        if (!"WARNING".equals(normalized)
                && !"MUTE".equals(normalized)
                && !"EVENT_CREATE_BAN".equals(normalized)
                && !"FULL_BAN".equals(normalized)) {
            throw new BadRequestException("Invalid sanction type");
        }

        return normalized;
    }

    public static class BadRequestException extends RuntimeException {
        public BadRequestException(String message) {
            super(message);
        }
    }

    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) {
            super(message);
        }
    }

    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) {
            super(message);
        }
    }
}
