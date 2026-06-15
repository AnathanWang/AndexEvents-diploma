package com.andexevents.users.util;

import com.andexevents.users.model.UserDto;

import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Rule-based match feed ranking (no ML):
 * incoming like → shared GOING events → common interests → distance → profile completeness.
 */
public final class MatchRecommendationScorer {

    static final int INCOMING_LIKE_BOOST = 1_000;
    static final int SHARED_GOING_EVENT_WEIGHT = 80;
    static final int COMMON_INTEREST_WEIGHT = 120;
    static final double DISTANCE_PENALTY_PER_KM = 3.0;
    static final int PROFILE_PHOTO_BOOST = 15;
    static final int PROFILE_BIO_BOOST = 5;
    static final int MISSING_PHOTO_PENALTY = 25;
    static final int MISSING_INTERESTS_PENALTY = 20;
    static final int MISSING_BIO_PENALTY = 10;
    static final int EMPTY_PROFILE_PENALTY = 60;

    private MatchRecommendationScorer() {
    }

    public static int score(
            UserDto candidate,
            UserDto currentUser,
            Set<String> incomingLikeUserIds,
            Map<String, Integer> sharedGoingEventCounts,
            double originLat,
            double originLon
    ) {
        int score = 0;

        if (incomingLikeUserIds != null && incomingLikeUserIds.contains(candidate.id())) {
            score += INCOMING_LIKE_BOOST;
        }

        if (sharedGoingEventCounts != null) {
            int sharedEvents = sharedGoingEventCounts.getOrDefault(candidate.id(), 0);
            score += Math.max(sharedEvents, 0) * SHARED_GOING_EVENT_WEIGHT;
        }

        score += countCommonInterests(currentUser.interests(), candidate.interests()) * COMMON_INTEREST_WEIGHT;

        Double candidateLat = candidate.lastLatitude();
        Double candidateLon = candidate.lastLongitude();
        if (candidateLat != null && candidateLon != null) {
            double distanceKm = haversineKm(originLat, originLon, candidateLat, candidateLon);
            score -= (int) Math.round(distanceKm * DISTANCE_PENALTY_PER_KM);
        }

        if (candidate.photoUrl() != null && !candidate.photoUrl().isBlank()) {
            score += PROFILE_PHOTO_BOOST;
        }
        if (candidate.bio() != null && !candidate.bio().isBlank()) {
            score += PROFILE_BIO_BOOST;
        }

        score -= profileCompletenessPenalty(candidate);

        return score;
    }

    static int profileCompletenessPenalty(UserDto candidate) {
        boolean hasPhoto = candidate.photoUrl() != null && !candidate.photoUrl().isBlank();
        boolean hasGallery = candidate.photos() != null && !candidate.photos().isEmpty();
        boolean hasBio = candidate.bio() != null && !candidate.bio().isBlank();
        boolean hasInterests = candidate.interests() != null && !candidate.interests().isEmpty();

        if (!hasPhoto && !hasGallery && !hasBio && !hasInterests) {
            return EMPTY_PROFILE_PENALTY;
        }

        int penalty = 0;
        if (!hasPhoto && !hasGallery) {
            penalty += MISSING_PHOTO_PENALTY;
        }
        if (!hasInterests) {
            penalty += MISSING_INTERESTS_PENALTY;
        }
        if (!hasBio) {
            penalty += MISSING_BIO_PENALTY;
        }
        return penalty;
    }

    public static List<UserDto> rank(
            List<UserDto> candidates,
            UserDto currentUser,
            Set<String> incomingLikeUserIds,
            Map<String, Integer> sharedGoingEventCounts,
            double originLat,
            double originLon,
            int limit
    ) {
        if (candidates == null || candidates.isEmpty()) {
            return List.of();
        }

        int safeLimit = Math.max(limit, 1);
        return candidates.stream()
                .sorted(Comparator
                        .comparingInt((UserDto c) -> score(
                                c,
                                currentUser,
                                incomingLikeUserIds,
                                sharedGoingEventCounts,
                                originLat,
                                originLon
                        ))
                        .reversed()
                        .thenComparing(UserDto::id))
                .limit(safeLimit)
                .collect(Collectors.toList());
    }

    static Set<String> normalizeInterests(List<String> interests) {
        if (interests == null || interests.isEmpty()) {
            return Set.of();
        }
        Set<String> normalized = new HashSet<>();
        for (String interest : interests) {
            if (interest == null) {
                continue;
            }
            String value = interest.trim().toLowerCase(Locale.ROOT);
            if (!value.isEmpty()) {
                normalized.add(value);
            }
        }
        return normalized;
    }

    static int countCommonInterests(List<String> left, List<String> right) {
        Set<String> a = normalizeInterests(left);
        Set<String> b = normalizeInterests(right);
        if (a.isEmpty() || b.isEmpty()) {
            return 0;
        }
        int count = 0;
        for (String item : a) {
            if (b.contains(item)) {
                count++;
            }
        }
        return count;
    }

    static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }
}
