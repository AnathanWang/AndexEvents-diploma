package com.andexevents.users.service;

import com.andexevents.users.model.UserDto;
import com.andexevents.users.repo.UserRepository;
import org.springframework.stereotype.Service;

import java.util.*;

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
        return userRepository.findById(userId);
    }

    public UserDto updateProfile(String userId, UpdateProfileRequest req) {
        Map<String, Object> updates = new LinkedHashMap<>();

        if (req.displayName() != null) updates.put("displayName", req.displayName());
        if (req.photoUrl() != null) updates.put("photoUrl", req.photoUrl());
        if (req.bio() != null) updates.put("bio", req.bio());
        if (req.age() != null) updates.put("age", req.age());
        if (req.gender() != null) updates.put("gender", req.gender());
        if (req.interests() != null) updates.put("interests", req.interests().toArray(new String[0]));
        if (req.socialLinks() != null) updates.put("socialLinks", req.socialLinks());
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

    public record UpdateProfileRequest(
            String displayName,
            String photoUrl,
            String bio,
            Integer age,
            String gender,
            List<String> interests,
            Map<String, Object> socialLinks,
            Boolean isOnboardingCompleted
    ) {
    }

    public static class ConflictException extends RuntimeException {
        public ConflictException(String message) {
            super(message);
        }
    }
}
