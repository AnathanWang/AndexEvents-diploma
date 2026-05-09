package com.andexevents.events.model;

import java.time.Instant;
import java.util.List;

public class EventDtos {
    public record CreatorDto(String id, String displayName, String photoUrl) {
    }

    public record CountDto(long participants) {
    }

    public record RatingDto(String id, String userId, String eventId,
                            int rating, String comment, Instant createdAt) {
    }

    public record EventRatingStatsDto(double averageRating, long ratingCount, Integer myRating) {
    }

    public record UserRatingDto(double averageRating, long eventsCount) {
    }

    public record UserPreviewDto(String id, String displayName, String photoUrl, String email) {
    }

    public record RatingReviewDto(String id, String userId, String eventId,
                                  int rating, String comment, Instant createdAt, UserPreviewDto user) {
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
            Double distance,
            EventRatingStatsDto ratingStats
    ) {
    }

    public record Pagination(int page, int limit, int total, int totalPages) {
    }

    public record NearbyEventsResponse(List<EventDto> events, Pagination pagination) {
    }
}
