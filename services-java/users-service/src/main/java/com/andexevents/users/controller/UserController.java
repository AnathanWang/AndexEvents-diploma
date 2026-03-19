package com.andexevents.users.controller;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.auth.AuthContext;
import com.andexevents.users.auth.AuthFilter;
import com.andexevents.users.model.AdminAuditLogDto;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.service.AdminAuditLogService;
import com.andexevents.users.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private static final String UNAUTHORIZED_MESSAGE = "Unauthorized: User ID not found";

    private final UserService userService;
    private final AdminAuditLogService adminAuditLogService;

    public UserController(UserService userService, AdminAuditLogService adminAuditLogService) {
        this.userService = userService;
        this.adminAuditLogService = adminAuditLogService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<UserDto>>> listUsersForModeration(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(UNAUTHORIZED_MESSAGE));
        }

        UserDto requester = userService.getById(auth.userId()).orElse(null);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: requester profile not found"));
        }

        if (!userService.isAdmin(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        List<UserDto> users = userService.getAllUsersForModeration();
        return ResponseEntity.ok(ApiResponse.ok(users));
    }

    @GetMapping("/admin/audit-logs")
    public ResponseEntity<ApiResponse<List<AdminAuditLogDto>>> getAdminAuditLogs(
            HttpServletRequest request,
            @RequestParam(defaultValue = "100") int limit
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(UNAUTHORIZED_MESSAGE));
        }

        UserDto requester = userService.getById(auth.userId()).orElse(null);
        if (requester == null || !userService.isAdmin(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        List<AdminAuditLogDto> logs = adminAuditLogService.getRecent(limit);
        return ResponseEntity.ok(ApiResponse.ok(logs));
    }

    @PutMapping("/{id}/role")
    public ResponseEntity<ApiResponse<UserDto>> updateUserRole(
            HttpServletRequest request,
            @PathVariable String id,
            @RequestBody UpdateRoleRequest body
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(UNAUTHORIZED_MESSAGE));
        }

        UserDto requester = userService.getById(auth.userId()).orElse(null);
        if (requester == null || !userService.isAdmin(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        if (id.equals(requester.id())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("Admin cannot change own role"));
        }

        try {
            String oldRole = requesterRole(userService.getById(id).orElse(null));
            UserDto updated = userService.updateUserRole(id, body.role());
            adminAuditLogService.logRoleChange(requester.id(), updated.id(), oldRole, requesterRole(updated));
            return ResponseEntity.ok(ApiResponse.ok(updated));
        } catch (UserService.BadRequestException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (UserService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        }
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
                null,
            null,
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

    @PostMapping("/me/photos")
    public ResponseEntity<ApiResponse<UserDto>> addPhoto(HttpServletRequest request, @RequestBody AddPhotoRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, null, "Unauthorized: User ID not found"));
        }

        UserDto updated = userService.addPhoto(auth.userId(), body.photoUrl());
        return ResponseEntity.ok(ApiResponse.ok(updated));
    }

    @DeleteMapping("/me/photos")
    public ResponseEntity<ApiResponse<UserDto>> removePhoto(HttpServletRequest request, @RequestBody RemovePhotoRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, null, "Unauthorized: User ID not found"));
        }

        UserDto updated = userService.removePhoto(auth.userId(), body.photoUrl());
        return ResponseEntity.ok(ApiResponse.ok(updated));
    }

    @PostMapping("/me/blocks")
    public ResponseEntity<ApiResponse<Void>> blockUser(HttpServletRequest request, @RequestBody BlockRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        userService.blockUser(auth.userId(), body.targetUserId());
        return ResponseEntity.ok(ApiResponse.okMessage("User blocked"));
    }

    @DeleteMapping("/me/blocks")
    public ResponseEntity<ApiResponse<Void>> unblockUser(HttpServletRequest request, @RequestBody BlockRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        userService.unblockUser(auth.userId(), body.targetUserId());
        return ResponseEntity.ok(ApiResponse.okMessage("User unblocked"));
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

    public record AddPhotoRequest(String photoUrl) {
    }

    public record RemovePhotoRequest(String photoUrl) {
    }

    public record BlockRequest(String targetUserId) {
    }

    public record UpdateRoleRequest(String role) {
    }

    private String requesterRole(UserDto user) {
        return user == null || user.role() == null ? "UNKNOWN" : user.role();
    }
}
