package com.andexevents.events.model;

import java.time.Instant;
import java.util.List;

public class EventDtos {
    public record CreatorDto(String id, String displayName, String photoUrl) {
    }

    public record CountDto(long participants) {
    }

    public record UserPreviewDto(String id, String displayName, String photoUrl, String email) {
    }

    public record ParticipantDto(String id, String userId, String eventId, String status, Instant joinedAt, Instant updatedAt, UserPreviewDto user) {
    }

    public record EventDto(
            String id,
            String title,
            String description,
            String category,
            String location,
            double latitude,
            double longitude,
            Instant dateTime,
            Instant endDateTime,
            double price,
            String imageUrl,
            List<String> imageUrls,
            boolean isOnline,
            String status,
            String rejectionReason,
            Integer maxParticipants,
            Integer minAge,
            Integer maxAge,
            String createdById,
            CreatorDto createdBy,
            List<ParticipantDto> participants,
            CountDto _count,
            long participantCount,
            boolean isParticipating,
            String userParticipationStatus,
            Double distance
    ) {
    }

    public record Pagination(int page, int limit, int total, int totalPages) {
    }

    public record NearbyEventsResponse(List<EventDto> events, Pagination pagination) {
    }
}
