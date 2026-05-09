package com.andexevents.users.controller;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.auth.AuthContext;
import com.andexevents.users.auth.AuthFilter;
import com.andexevents.users.model.AdminAuditLogDto;
import com.andexevents.users.model.UserSanctionDto;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.service.AdminAuditLogService;
import com.andexevents.users.service.UserSanctionService;
import com.andexevents.users.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private static final String UNAUTHORIZED_MESSAGE = "Unauthorized: User ID not found";

    private final UserService userService;
    private final AdminAuditLogService adminAuditLogService;
    private final UserSanctionService userSanctionService;

    public UserController(
            UserService userService,
            AdminAuditLogService adminAuditLogService,
            UserSanctionService userSanctionService
    ) {
        this.userService = userService;
        this.adminAuditLogService = adminAuditLogService;
        this.userSanctionService = userSanctionService;
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

        if (!userService.canModerate(requester)) {
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
        if (requester == null || !userService.canModerate(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        List<AdminAuditLogDto> logs = adminAuditLogService.getRecent(limit);
        return ResponseEntity.ok(ApiResponse.ok(logs));
    }

    @GetMapping("/admin/sanctions")
    public ResponseEntity<ApiResponse<List<UserSanctionDto>>> getAdminSanctions(
            HttpServletRequest request,
            @RequestParam(required = false) String targetUserId,
            @RequestParam(defaultValue = "200") int limit
    ) {
        UserDto requester = resolveAdminRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        if (targetUserId != null && !targetUserId.isBlank()) {
            try {
                return ResponseEntity.ok(ApiResponse.ok(userSanctionService.getByTargetUser(targetUserId)));
            } catch (UserSanctionService.BadRequestException e) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(ApiResponse.error(e.getMessage()));
            }
        }

        return ResponseEntity.ok(ApiResponse.ok(userSanctionService.getActiveAll(limit)));
    }

    @PostMapping("/admin/sanctions")
    public ResponseEntity<ApiResponse<UserSanctionDto>> createSanction(
            HttpServletRequest request,
            @Valid @RequestBody CreateSanctionRequest body
    ) {
        UserDto requester = resolveAdminRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        try {
            Instant expiresAt = null;
            if (body.expiresAt() != null && !body.expiresAt().isBlank()) {
                expiresAt = Instant.parse(body.expiresAt());
            }

            UserSanctionDto sanction = userSanctionService.createSanction(
                    body.targetUserId(),
                    requester.id(),
                    body.type(),
                    body.reason(),
                    expiresAt
            );

            adminAuditLogService.logSanctionCreated(
                    requester.id(),
                    sanction.targetUserId(),
                    sanction.type(),
                    sanction.reason(),
                    sanction.expiresAt() == null ? null : sanction.expiresAt().toString()
            );

            return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(sanction));
        } catch (UserSanctionService.BadRequestException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (UserSanctionService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("Invalid sanction payload"));
        }
    }

    @PutMapping("/admin/sanctions/{sanctionId}/revoke")
    public ResponseEntity<ApiResponse<Void>> revokeSanction(
            HttpServletRequest request,
            @PathVariable String sanctionId
    ) {
        UserDto requester = resolveAdminRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        try {
            UserSanctionDto sanction = userSanctionService.getById(sanctionId);

            userSanctionService.revoke(sanctionId, requester.id());

            adminAuditLogService.logSanctionRevoked(
                    requester.id(),
                sanction.targetUserId(),
                    sanctionId
            );

            return ResponseEntity.ok(ApiResponse.okMessage("Sanction revoked"));
        } catch (UserSanctionService.BadRequestException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (UserSanctionService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        }
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
        if (requester == null || !userService.canModerate(requester)) {
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

    @GetMapping("/me/sanctions")
    public ResponseEntity<ApiResponse<List<UserSanctionDto>>> mySanctions(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(UNAUTHORIZED_MESSAGE));
        }

        try {
            List<UserSanctionDto> sanctions = userSanctionService.getByTargetUser(auth.userId());
            return ResponseEntity.ok(ApiResponse.ok(sanctions));
        } catch (UserSanctionService.BadRequestException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        }
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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
            null,
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

        String sanctionError = validateSelfMutationAccess(auth.userId());
        if (sanctionError != null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(sanctionError));
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

    public record CreateSanctionRequest(
            @NotBlank(message = "targetUserId is required")
            String targetUserId,
            @NotBlank(message = "type is required")
            String type,
            @NotBlank(message = "reason is required")
            String reason,
            String expiresAt
    ) {
    }

    private String requesterRole(UserDto user) {
        return user == null || user.role() == null ? "UNKNOWN" : user.role();
    }

    private UserDto resolveAdminRequester(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return null;
        }

        UserDto requester = userService.getById(auth.userId()).orElse(null);
        if (requester == null || !userService.canModerate(requester)) {
            return null;
        }

        return requester;
    }

    private String validateSelfMutationAccess(String userId) {
        try {
            userSanctionService.assertCanMutateOwnProfile(userId);
            return null;
        } catch (UserSanctionService.ForbiddenException e) {
            return e.getMessage();
        }
    }
}
