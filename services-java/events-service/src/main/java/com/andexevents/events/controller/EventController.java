package com.andexevents.events.controller;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.auth.AuthContext;
import com.andexevents.events.auth.AuthFilter;
import com.andexevents.events.model.EventDtos;
import com.andexevents.events.repo.EventRepository;
import com.andexevents.events.service.EventService;
import com.andexevents.events.service.EventModerationGuardService;
import com.andexevents.events.service.ModerationAccessService;
import com.andexevents.events.service.UserSanctionGuardService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/events")
public class EventController {
    private final EventService eventService;
    private final UserSanctionGuardService userSanctionGuardService;
    private final ModerationAccessService moderationAccessService;

    public EventController(
            EventService eventService,
            UserSanctionGuardService userSanctionGuardService,
            ModerationAccessService moderationAccessService
    ) {
        this.eventService = eventService;
        this.userSanctionGuardService = userSanctionGuardService;
        this.moderationAccessService = moderationAccessService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<EventDtos.EventDto>> createEvent(HttpServletRequest request, @RequestBody CreateEventRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found in database"));
        }

        try {
            userSanctionGuardService.assertCanCreateEvent(auth.userId());
        } catch (UserSanctionGuardService.ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(e.getMessage()));
        }

        EventRepository.EventCreateParams params = new EventRepository.EventCreateParams(
                body.title(),
                body.description(),
                body.category(),
                body.location(),
                body.latitude(),
                body.longitude(),
                Instant.parse(body.dateTime()),
                body.endDateTime() != null ? Instant.parse(body.endDateTime()) : null,
                body.price(),
                body.imageUrl(),
            body.imageUrls(),
                body.isOnline(),
                auth.userId()
        );

        EventDtos.EventDto created = eventService.create(params);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(created));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Object>> getAllEvents(
            HttpServletRequest request,
            @RequestParam(required = false) Double latitude,
            @RequestParam(required = false) Double longitude,
            @RequestParam(required = false) Integer maxDistance,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer limit,

            // Go-compatible aliases
            @RequestParam(required = false, name = "lat") Double lat,
            @RequestParam(required = false, name = "lon") Double lon,
            @RequestParam(required = false, name = "radius") Integer radius,
            @RequestParam(required = false, name = "pageSize") Integer pageSize
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        String viewerUserId = auth == null ? null : auth.userId();

        Double effectiveLat = latitude != null ? latitude : lat;
        Double effectiveLon = longitude != null ? longitude : lon;

        if (effectiveLat != null && effectiveLon != null) {
            if (effectiveLat < -90 || effectiveLat > 90 || effectiveLon < -180 || effectiveLon > 180) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(ApiResponse.error("Invalid coordinates"));
            }

            int dist = maxDistance != null ? maxDistance : (radius != null ? radius : 50000);
            int pageNum = page != null ? page : 1;
            int limitNum = limit != null ? limit : (pageSize != null ? pageSize : 20);

            EventDtos.NearbyEventsResponse resp = eventService.listNearby(
                    effectiveLat,
                    effectiveLon,
                    dist,
                    category,
                    pageNum,
                    limitNum,
                    viewerUserId
            );

            return ResponseEntity.ok(ApiResponse.ok(resp));
        }

        List<EventDtos.EventDto> events = eventService.listAllApproved(viewerUserId);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("events", events)));
    }

    @GetMapping("/moderation/all")
    public ResponseEntity<ApiResponse<Object>> listAllEventsForModeration(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        if (!moderationAccessService.canModerate(auth.userId())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error("Недостаточно прав"));
        }
        List<EventDtos.EventDto> events = eventService.listAllApprovedForModeration(auth.userId());
        return ResponseEntity.ok(ApiResponse.ok(Map.of("events", events)));
    }

    @GetMapping("/user/{userId}")
    public ApiResponse<List<EventDtos.EventDto>> getUserEvents(@PathVariable String userId) {
        return ApiResponse.ok(eventService.listUserEvents(userId));
    }

    @GetMapping("/user/{userId}/participated")
    public ApiResponse<List<EventDtos.EventDto>> getUserParticipatedEvents(@PathVariable String userId) {
        return ApiResponse.ok(eventService.listUserParticipatedEvents(userId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EventDtos.EventDto>> getEventById(HttpServletRequest request, @PathVariable String id) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        String viewerUserId = auth == null ? null : auth.userId();

        EventDtos.EventDto event = eventService.getById(id, viewerUserId).orElse(null);
        if (event == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Event not found"));
        }

        return ResponseEntity.ok(ApiResponse.ok(event));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<EventDtos.EventDto>> updateEvent(HttpServletRequest request, @PathVariable String id, @RequestBody UpdateEventRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }

        EventRepository.EventUpdateParams p = new EventRepository.EventUpdateParams(
                body.title(),
                body.description(),
                body.category(),
                body.location(),
                body.latitude(),
                body.longitude(),
                body.dateTime() == null ? null : Instant.parse(body.dateTime()),
                body.endDateTime() == null ? null : Instant.parse(body.endDateTime()),
                body.price(),
                body.imageUrl(),
            body.imageUrls(),
                body.isOnline()
        );

        try {
            EventDtos.EventDto updated = eventService.update(id, auth.userId(), p).orElse(null);
            if (updated == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Event not found"));
            }
            return ResponseEntity.ok(ApiResponse.ok(updated));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEvent(HttpServletRequest request, @PathVariable String id) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }

        try {
            boolean deleted;
            try {
                deleted = eventService.delete(id, auth.userId());
            } catch (EventService.ForbiddenException ex) {
                // allow moderators/admins to delete events (moderation action)
                if (!moderationAccessService.canModerate(auth.userId())) {
                    throw ex;
                }

                deleted = eventService.deleteAsModerator(id);
            }
            if (!deleted) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Event not found"));
            }
            return ResponseEntity.ok(ApiResponse.okMessage("Event deleted successfully"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @PostMapping("/{id}/participate")
    public ResponseEntity<ApiResponse<Object>> participate(HttpServletRequest request, @PathVariable String id, @RequestBody ParticipateRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found in database"));
        }

        if (body.status() == null || (!body.status().equals("GOING") && !body.status().equals("INTERESTED"))) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error("Invalid request data"));
        }

        try {
            var participation = eventService.participate(id, auth.userId(), body.status());
            return ResponseEntity.ok(new ApiResponse<>(true, participation, "Participation status updated"));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.BadRequestException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
        } catch (EventModerationGuardService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @DeleteMapping("/{id}/participate")
    public ResponseEntity<ApiResponse<Object>> cancelParticipation(HttpServletRequest request, @PathVariable String id) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found in database"));
        }

        var deleted = eventService.cancelParticipation(id, auth.userId());
        return ResponseEntity.ok(new ApiResponse<>(true, deleted, "Participation cancelled successfully"));
    }

    @GetMapping("/{id}/participants")
    public ResponseEntity<ApiResponse<Object>> getParticipants(@PathVariable String id) {
        try {
            var participants = eventService.getParticipants(id);
            return ResponseEntity.ok(ApiResponse.ok(participants));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    // ── Rating endpoints ───────────────────────────────────────────────────

    @PostMapping("/{id}/rating")
    public ResponseEntity<ApiResponse<EventDtos.RatingDto>> rateEvent(
            HttpServletRequest request,
            @PathVariable String id,
            @RequestBody RatingRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            EventDtos.RatingDto dto = eventService.rateEvent(id, auth.userId(), body.rating(), body.comment());
            return ResponseEntity.ok(ApiResponse.ok(dto));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.BadRequestException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @GetMapping("/{id}/rating/stats")
    public ResponseEntity<ApiResponse<EventDtos.EventRatingStatsDto>> getEventRatingStats(
            HttpServletRequest request,
            @PathVariable String id) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        String viewerUserId = auth == null ? null : auth.userId();
        try {
            EventDtos.EventRatingStatsDto stats = eventService.getEventRatingStats(id, viewerUserId);
            return ResponseEntity.ok(ApiResponse.ok(stats));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @GetMapping("/{id}/rating/reviews")
    public ResponseEntity<ApiResponse<List<EventDtos.RatingReviewDto>>> getEventRatingReviews(
            HttpServletRequest request,
            @PathVariable String id) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        String viewerUserId = auth == null ? null : auth.userId();
        try {
            List<EventDtos.RatingReviewDto> reviews = eventService.getEventReviews(id, viewerUserId);
            return ResponseEntity.ok(ApiResponse.ok(reviews));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @GetMapping("/user/{userId}/rating")
    public ResponseEntity<ApiResponse<EventDtos.UserRatingDto>> getUserRating(@PathVariable String userId) {
        try {
            EventDtos.UserRatingDto dto = eventService.getUserRating(userId);
            return ResponseEntity.ok(ApiResponse.ok(dto));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    public record CreateEventRequest(
            @NotBlank String title,
            @NotBlank String description,
            @NotBlank String category,
            @NotBlank String location,
            @NotNull Double latitude,
            @NotNull Double longitude,
            @NotBlank String dateTime,
            String endDateTime,
            Double price,
            String imageUrl,
            List<String> imageUrls,
            Boolean isOnline
    ) {
    }

    public record UpdateEventRequest(
            String title,
            String description,
            String category,
            String location,
            Double latitude,
            Double longitude,
            String dateTime,
            String endDateTime,
            Double price,
            String imageUrl,
            List<String> imageUrls,
            Boolean isOnline
    ) {
    }

    public record ParticipateRequest(String status) {
    }

    public record RatingRequest(int rating, String comment) {
    }
}
