package com.andexevents.users.service;

import com.andexevents.users.model.UserDto;
import com.andexevents.users.repo.UserRepository;
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

        return userRepository.updateProfile(userId, updates);
    }

    public void updateLocation(String userId, double latitude, double longitude) {
        userRepository.updateLocation(userId, latitude, longitude);
    }

    public List<UserDto> getMatches(String userId, Double latitude, Double longitude, double radiusKm, int limit) {
        UserDto current = userRepository.findById(userId).orElse(null);
        if (current == null) return List.of();

        Double userLat = latitude != null ? latitude : current.lastLatitude();
        Double userLon = longitude != null ? longitude : current.lastLongitude();
        if (userLat == null || userLon == null) return List.of();

        return userRepository.findMatches(
                userId,
                userLat,
                userLon,
                radiusKm,
                limit,
                current.minAge(),
                current.maxAge()
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
            Boolean isOnboardingCompleted
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
