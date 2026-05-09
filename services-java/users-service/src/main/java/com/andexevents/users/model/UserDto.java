package com.andexevents.users.model;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public record UserDto(
        String id,
        String firebaseUid,
        String email,
        String displayName,
        String photoUrl,
        String coverImageUrl,
        List<String> photos,
        String bio,
        List<String> interests,
        Map<String, Object> socialLinks,
        Integer age,
        String gender,
        String role,
        Double lastLatitude,
        Double lastLongitude,
        Instant lastLocationUpdate,
        Boolean isProfileVisible,
        Boolean isLocationVisible,
        Integer minAge,
        Integer maxAge,
        Integer maxDistance,
        Boolean showVisitedEvents,
        Boolean showInMatches,
        Boolean incognitoMode,
        Boolean hideOnlineStatus,
        String fcmToken,
        Boolean isOnboardingCompleted,
        Instant createdAt,
        Instant updatedAt,
        // Organizer rating (null if user has fewer than 3 approved events)
        Double averageRating,
        Long eventsCreatedCount
) {
}
