package com.andexevents.events.controller;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.auth.AuthContext;
import com.andexevents.events.auth.AuthFilter;
import com.andexevents.events.repo.WaitlistRepository;
import com.andexevents.events.service.EventService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class WaitlistController {
    private final EventService eventService;

    public WaitlistController(EventService eventService) {
        this.eventService = eventService;
    }

    @GetMapping("/api/events/{eventId}/waitlist")
    public ResponseEntity<ApiResponse<Object>> list(HttpServletRequest request, @PathVariable String eventId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            List<WaitlistRepository.WaitlistEntryRow> rows = eventService.listWaitlist(eventId, auth.userId());
            return ResponseEntity.ok(ApiResponse.ok(Map.of("waitlist", rows)));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @PutMapping("/api/events/{eventId}/waitlist/{userId}/approve")
    public ResponseEntity<ApiResponse<Void>> approve(HttpServletRequest request, @PathVariable String eventId, @PathVariable String userId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.approveWaitlist(eventId, userId, auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.BadRequestException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @PutMapping("/api/events/{eventId}/waitlist/{userId}/reject")
    public ResponseEntity<ApiResponse<Void>> reject(HttpServletRequest request, @PathVariable String eventId, @PathVariable String userId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.rejectWaitlist(eventId, userId, auth.userId());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        } catch (EventService.NotFoundException ex) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(ex.getMessage()));
        }
    }
}

