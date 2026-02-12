package com.andexevents.users.controller;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.auth.AuthContext;
import com.andexevents.users.auth.AuthFilter;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<UserDto>> createUser(HttpServletRequest request, @RequestBody CreateUserRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.uid() == null || auth.uid().isBlank() || auth.email() == null || auth.email().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, null, "Unauthorized: valid token with uid/email is required"));
        }

        UserDto user = userService.createUser(auth.uid(), auth.email(), body.displayName(), body.photoUrl());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(user));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> me(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, null, "Unauthorized: User ID not found"));
        }

        UserDto user = userService.getById(auth.userId()).orElse(null);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ApiResponse<>(false, null, "User not found"));
        }

        return ResponseEntity.ok(ApiResponse.ok(user));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserDto>> getById(@PathVariable String id) {
        UserDto user = userService.getById(id).orElse(null);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ApiResponse<>(false, null, "User not found"));
        }
        return ResponseEntity.ok(ApiResponse.ok(user));
    }

    @PostMapping("/me/onboarding")
    public ResponseEntity<ApiResponse<UserDto>> completeOnboarding(HttpServletRequest request, @RequestBody OnboardingRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        UserService.UpdateProfileRequest update = new UserService.UpdateProfileRequest(
                body.displayName(),
                body.photoUrl(),
                body.bio(),
                body.age(),
                body.gender(),
                body.interests(),
                body.socialLinks(),
                true
        );

        UserDto updated = userService.updateProfile(auth.userId(), update);
        return ResponseEntity.ok(ApiResponse.ok(updated));
    }

    @PutMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> updateMe(HttpServletRequest request, @RequestBody UserService.UpdateProfileRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, null, "Unauthorized: User ID not found"));
        }

        UserDto updated = userService.updateProfile(auth.userId(), body);
        return ResponseEntity.ok(ApiResponse.ok(updated));
    }

    @PutMapping("/me/location")
    public ResponseEntity<ApiResponse<Void>> updateLocation(HttpServletRequest request, @RequestBody UpdateLocationRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        if (body.latitude() < -90 || body.latitude() > 90 || body.longitude() < -180 || body.longitude() > 180) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180"));
        }

        userService.updateLocation(auth.userId(), body.latitude(), body.longitude());
        return ResponseEntity.ok(ApiResponse.okMessage("Location updated successfully"));
    }

    @GetMapping("/matches")
    public ResponseEntity<ApiResponse<List<UserDto>>> matches(
            HttpServletRequest request,
            @RequestParam(required = false) Double latitude,
            @RequestParam(required = false) Double longitude,
            @RequestParam(defaultValue = "50") double radiusKm,
            @RequestParam(defaultValue = "20") int limit
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        if (latitude != null && longitude != null) {
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(ApiResponse.error("Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180"));
            }
        }

        List<UserDto> matches = userService.getMatches(auth.userId(), latitude, longitude, radiusKm, limit);
        return ResponseEntity.ok(ApiResponse.ok(matches));
    }

    public record CreateUserRequest(String displayName, String photoUrl) {
    }

        public record OnboardingRequest(
            String displayName,
            String photoUrl,
            String bio,
            Integer age,
            String gender,
            java.util.List<String> interests,
            java.util.Map<String, Object> socialLinks
        ) {
        }

    public record UpdateLocationRequest(@NotNull Double latitude, @NotNull Double longitude) {
    }
}
