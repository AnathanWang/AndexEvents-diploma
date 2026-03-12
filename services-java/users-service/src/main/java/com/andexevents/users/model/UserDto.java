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
        String fcmToken,
        Boolean isOnboardingCompleted,
        Instant createdAt,
        Instant updatedAt
) {
}
