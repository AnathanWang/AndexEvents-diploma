package com.andexevents.events.service;

import com.andexevents.events.model.EventSanctionDto;
import com.andexevents.events.model.EventSanctionType;
import com.andexevents.events.repo.EventRepository;
import com.andexevents.events.repo.EventSanctionRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class EventSanctionService {
    private final EventRepository eventRepository;
    private final EventSanctionRepository eventSanctionRepository;
    private final ModerationAccessService moderationAccessService;

    public EventSanctionService(
            EventRepository eventRepository,
            EventSanctionRepository eventSanctionRepository,
            ModerationAccessService moderationAccessService
    ) {
        this.eventRepository = eventRepository;
        this.eventSanctionRepository = eventSanctionRepository;
        this.moderationAccessService = moderationAccessService;
    }

    public EventSanctionDto create(
            String requesterUserId,
            String eventId,
            EventSanctionType type,
            String reason,
            Instant expiresAt
    ) {
        if (!moderationAccessService.canModerate(requesterUserId)) {
            throw new ForbiddenException("Forbidden: moderation access required");
        }

        if (reason == null || reason.trim().isEmpty()) {
            throw new BadRequestException("Sanction reason is required");
        }

        eventRepository.findEventRowById(eventId).orElseThrow(
                () -> new NotFoundException("Event not found: " + eventId)
        );

        // For HIDE_VISIBILITY we want an automatic return to public feeds.
        // If moderator didn't specify expiry, default to a short TTL.
        Instant effectiveExpiresAt = expiresAt;
        if (type == EventSanctionType.HIDE_VISIBILITY && effectiveExpiresAt == null) {
            effectiveExpiresAt = Instant.now().plus(7, ChronoUnit.DAYS);
        }

        return eventSanctionRepository.create(
                eventId,
                type,
                reason.trim(),
                effectiveExpiresAt,
                requesterUserId
        );
    }

    public void revoke(String requesterUserId, String sanctionId) {
        if (!moderationAccessService.canModerate(requesterUserId)) {
            throw new ForbiddenException("Forbidden: moderation access required");
        }
        eventSanctionRepository.revoke(sanctionId, requesterUserId);
    }

    public List<EventSanctionDto> listActive(String requesterUserId, String eventId) {
        if (!moderationAccessService.canModerate(requesterUserId)) {
            throw new ForbiddenException("Forbidden: moderation access required");
        }
        return eventSanctionRepository.listActiveByEventId(eventId);
    }

    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) {
            super(message);
        }
    }

    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) {
            super(message);
        }
    }

    public static class BadRequestException extends RuntimeException {
        public BadRequestException(String message) {
            super(message);
        }
    }
}

