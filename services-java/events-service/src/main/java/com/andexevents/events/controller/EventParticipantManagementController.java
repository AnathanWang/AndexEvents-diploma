package com.andexevents.events.controller;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.auth.AuthContext;
import com.andexevents.events.auth.AuthFilter;
import com.andexevents.events.service.EventService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class EventParticipantManagementController {
    private final EventService eventService;

    public EventParticipantManagementController(EventService eventService) {
        this.eventService = eventService;
    }

    @GetMapping("/api/events/{eventId}/participants/manage")
    public ResponseEntity<ApiResponse<Object>> listManage(HttpServletRequest request, @PathVariable String eventId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            List<EventService.ManageParticipant> items = eventService.getParticipantsForManage(eventId, auth.userId());
            return ResponseEntity.ok(ApiResponse.ok(Map.of("participants", items)));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @DeleteMapping("/api/events/{eventId}/participants/{userId}")
    public ResponseEntity<ApiResponse<Void>> kick(HttpServletRequest request, @PathVariable String eventId, @PathVariable String userId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.kickParticipant(eventId, userId, auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    public record BanRequest(String userId, String reason) {}

    @GetMapping("/api/events/{eventId}/bans")
    public ResponseEntity<ApiResponse<Object>> listBans(HttpServletRequest request, @PathVariable String eventId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            var banned = eventService.listEventBans(eventId, auth.userId());
            return ResponseEntity.ok(ApiResponse.ok(Map.of("banned", banned)));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @PostMapping("/api/events/{eventId}/bans")
    public ResponseEntity<ApiResponse<Void>> ban(HttpServletRequest request, @PathVariable String eventId, @RequestBody BanRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        if (body == null || body.userId() == null || body.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error("Invalid request"));
        }
        try {
            eventService.banUserForEvent(eventId, body.userId(), body.reason(), auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @DeleteMapping("/api/events/{eventId}/bans/{userId}")
    public ResponseEntity<ApiResponse<Void>> unban(HttpServletRequest request, @PathVariable String eventId, @PathVariable String userId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.unbanUserForEvent(eventId, userId, auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    public record CheckInRequest(boolean checkedIn) {}

    @PutMapping("/api/events/{eventId}/checkin/{userId}")
    public ResponseEntity<ApiResponse<Void>> checkIn(HttpServletRequest request, @PathVariable String eventId, @PathVariable String userId, @RequestBody CheckInRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.setCheckIn(eventId, userId, body != null && body.checkedIn(), auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.BadRequestException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @PutMapping("/api/events/{eventId}/checkin/me")
    public ResponseEntity<ApiResponse<Void>> checkInMe(HttpServletRequest request, @PathVariable String eventId, @RequestBody CheckInRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.setCheckIn(eventId, auth.userId(), body != null && body.checkedIn(), auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.BadRequestException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
        }
    }
}

