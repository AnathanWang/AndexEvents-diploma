package com.andexevents.users.service;

import com.andexevents.users.model.MapUserDto;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.model.GlobalMatchContext;
import com.andexevents.users.repo.UserRepository;
import com.andexevents.users.util.MatchRecommendationScorer;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.Locale;

@Service
public class UserService {
    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserDto createUser(String firebaseUid, String email, String displayName, String photoUrl) {
        Optional<UserDto> existing = userRepository.findByEmail(email);
        if (existing.isPresent()) {
            UserDto user = existing.get();

            if (user.firebaseUid() == null || user.firebaseUid().isBlank()) {
                return userRepository.updateFirebaseUid(user.id(), firebaseUid);
            }

            if (firebaseUid.equals(user.firebaseUid())) {
                return user;
            }

            throw new ConflictException("User with this email already exists");
        }

        String id = UUID.randomUUID().toString();
        return userRepository.insertUser(id, firebaseUid, email, displayName == null ? "" : displayName, photoUrl == null ? "" : photoUrl);
    }

    public Optional<UserDto> getById(String userId) {
        return userRepository.findByIdWithRating(userId);
    }

    public List<UserDto> getAllUsersForModeration() {
        return userRepository.findAllForModeration();
    }

    public boolean isAdmin(UserDto user) {
        return "ADMIN".equals(normalizeRole(user == null ? null : user.role()));
    }

    public boolean canModerate(UserDto user) {
        String normalizedRole = normalizeRole(user == null ? null : user.role());
        return "ADMIN".equals(normalizedRole) || "MODERATOR".equals(normalizedRole);
    }

    @Transactional
    public UserDto updateUserRole(String targetUserId, String role) {
        String normalizedRole = normalizeRole(role);
        if (!"USER".equals(normalizedRole)
                && !"MODERATOR".equals(normalizedRole)
                && !"ADMIN".equals(normalizedRole)) {
            throw new BadRequestException("Invalid role. Allowed values: USER, MODERATOR, ADMIN");
        }

        if (targetUserId == null || targetUserId.isBlank()) {
            throw new BadRequestException("targetUserId is required");
        }

        if (userRepository.findById(targetUserId).isEmpty()) {
            throw new NotFoundException("User not found");
        }

        return userRepository.updateRole(targetUserId, normalizedRole);
    }

    private String normalizeRole(String role) {
        if (role == null) {
            return "";
        }

        return role.trim().toUpperCase(Locale.ROOT);
    }

    public UserDto updateProfile(String userId, UpdateProfileRequest req) {
        Map<String, Object> updates = new LinkedHashMap<>();

        if (req.displayName() != null) updates.put("displayName", req.displayName());
        if (req.photoUrl() != null) updates.put("photoUrl", req.photoUrl());
        if (req.coverImageUrl() != null) updates.put("coverImageUrl", req.coverImageUrl());
        if (req.photos() != null) updates.put("photos", req.photos().toArray(new String[0]));
        if (req.bio() != null) updates.put("bio", req.bio());
        if (req.age() != null) updates.put("age", req.age());
        if (req.gender() != null) updates.put("gender", req.gender());
        if (req.interests() != null) updates.put("interests", req.interests().toArray(new String[0]));
        if (req.socialLinks() != null) updates.put("socialLinks", req.socialLinks());
        if (req.fcmToken() != null) updates.put("fcmToken", req.fcmToken());
        if (req.isOnboardingCompleted() != null) updates.put("isOnboardingCompleted", req.isOnboardingCompleted());
        if (req.showVisitedEvents() != null) updates.put("showVisitedEvents", req.showVisitedEvents());
        if (req.showInMatches() != null) updates.put("showInMatches", req.showInMatches());
        if (req.incognitoMode() != null) updates.put("incognitoMode", req.incognitoMode());
        if (req.hideOnlineStatus() != null) updates.put("hideOnlineStatus", req.hideOnlineStatus());
        if (Boolean.TRUE.equals(req.clearMinAge())) {
            updates.put("minAge", null);
        } else if (req.minAge() != null) {
            updates.put("minAge", req.minAge());
        }
        if (Boolean.TRUE.equals(req.clearMaxAge())) {
            updates.put("maxAge", null);
        } else if (req.maxAge() != null) {
            updates.put("maxAge", req.maxAge());
        }
        if (Boolean.TRUE.equals(req.clearMatchGenderPreference())) {
            updates.put("matchGenderPreference", null);
        } else if (req.matchGenderPreference() != null) {
            updates.put("matchGenderPreference", req.matchGenderPreference());
        }

        return userRepository.updateProfile(userId, updates);
    }

    public void updateLocation(String userId, double latitude, double longitude) {
        userRepository.updateLocation(userId, latitude, longitude);
    }

    public void touchPresence(String userId) {
        userRepository.touchPresence(userId);
    }

    public List<String> listBlockedUserIds(String userId) {
        return userRepository.listBlockedUserIds(userId);
    }

    public List<UserDto> getMatches(String userId, Double latitude, Double longitude, double radiusKm, int limit) {
        UserDto current = userRepository.findById(userId).orElse(null);
        if (current == null) return List.of();

        Double userLat = latitude != null ? latitude : current.lastLatitude();
        Double userLon = longitude != null ? longitude : current.lastLongitude();
        if (userLat == null || userLon == null) return List.of();

        int poolSize = Math.min(Math.max(limit * 4, 40), 80);
        GlobalMatchContext context = userRepository.findGlobalMatchContext(userId);
        List<UserDto> candidates = userRepository.findMatches(
                userId,
                userLat,
                userLon,
                radiusKm,
                poolSize,
                current.minAge(),
                current.maxAge(),
                current.matchGenderPreference()
        );

        List<String> candidateIds = candidates.stream().map(UserDto::id).toList();
        Map<String, Integer> sharedGoingEvents = userRepository.findSharedGoingEventCounts(userId, candidateIds);

        return MatchRecommendationScorer.rank(
                candidates,
                current,
                context.incomingLikeUserIds(),
                sharedGoingEvents,
                userLat,
                userLon,
                limit
        );
    }

    public UserDto addPhoto(String userId, String photoUrl) {
        userRepository.addPhoto(userId, photoUrl);
        return userRepository.findById(userId).orElseThrow();
    }

    public UserDto removePhoto(String userId, String photoUrl) {
        userRepository.removePhoto(userId, photoUrl);
        return userRepository.findById(userId).orElseThrow();
    }

    public void blockUser(String userId, String targetUserId) {
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new BadRequestException("targetUserId is required");
        }
        if (userId.equals(targetUserId)) {
            throw new BadRequestException("Cannot block yourself");
        }
        userRepository.blockUser(userId, targetUserId);
    }

    public void unblockUser(String userId, String targetUserId) {
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new BadRequestException("targetUserId is required");
        }
        userRepository.unblockUser(userId, targetUserId);
    }

    public List<MapUserDto> getMapUsers(String userId, double latitude, double longitude, double radiusKm, int limit) {
        return userRepository.findMapUsers(userId, latitude, longitude, radiusKm, limit);
    }

    public record UpdateProfileRequest(
            String displayName,
            String photoUrl,
            String coverImageUrl,
            List<String> photos,
            String bio,
            Integer age,
            String gender,
            List<String> interests,
            Map<String, Object> socialLinks,
            String fcmToken,
            Boolean isOnboardingCompleted,
            Boolean showVisitedEvents,
            Boolean showInMatches,
            Boolean incognitoMode,
            Boolean hideOnlineStatus,
            Integer minAge,
            Integer maxAge,
            Boolean clearMinAge,
            Boolean clearMaxAge,
            String matchGenderPreference,
            Boolean clearMatchGenderPreference
    ) {
    }

    public static class ConflictException extends RuntimeException {
        public ConflictException(String message) {
            super(message);
        }
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
}
