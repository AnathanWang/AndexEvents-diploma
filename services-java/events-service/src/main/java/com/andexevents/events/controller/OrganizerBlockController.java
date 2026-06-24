package com.andexevents.events.controller;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.auth.AuthContext;
import com.andexevents.events.auth.AuthFilter;
import com.andexevents.events.service.EventService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/events/organizer/blocks")
public class OrganizerBlockController {
    private final EventService eventService;

    public OrganizerBlockController(EventService eventService) {
        this.eventService = eventService;
    }

    public record BlockRequest(String blockedUserId, String reason) {}

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> block(HttpServletRequest request, @RequestBody BlockRequest body) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        if (body == null || body.blockedUserId() == null || body.blockedUserId().isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error("Invalid request"));
        }
        try {
            eventService.blockUserGlobally(auth.userId(), body.blockedUserId(), body.reason());
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Object>> list(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            var blocked = eventService.listGlobalBlockedUsers(auth.userId());
            return ResponseEntity.ok(ApiResponse.ok(Map.of("blocked", blocked)));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }

    @DeleteMapping("/{blockedUserId}")
    public ResponseEntity<ApiResponse<Void>> unblock(HttpServletRequest request, @PathVariable String blockedUserId) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error("Unauthorized"));
        }
        try {
            eventService.unblockUserGlobally(auth.userId(), blockedUserId);
            return ResponseEntity.ok(ApiResponse.okMessage("OK"));
        } catch (EventService.ForbiddenException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(ex.getMessage()));
        }
    }
}

