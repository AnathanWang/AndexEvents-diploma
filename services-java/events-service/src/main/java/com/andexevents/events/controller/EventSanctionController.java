package com.andexevents.events.controller;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.auth.AuthContext;
import com.andexevents.events.auth.AuthFilter;
import com.andexevents.events.model.EventSanctionDto;
import com.andexevents.events.model.EventSanctionType;
import com.andexevents.events.service.EventSanctionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/events")
public class EventSanctionController {
    private final EventSanctionService eventSanctionService;

    public EventSanctionController(EventSanctionService eventSanctionService) {
        this.eventSanctionService = eventSanctionService;
    }

    @PostMapping("/{eventId}/sanctions")
    public ResponseEntity<ApiResponse<EventSanctionDto>> createSanction(
            HttpServletRequest request,
            @PathVariable String eventId,
            @RequestBody CreateEventSanctionRequest body
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized"));
        }

        try {
            EventSanctionDto created = eventSanctionService.create(
                    auth.userId(),
                    eventId,
                    EventSanctionType.valueOf(body.type()),
                    body.reason(),
                    body.expiresAt() == null ? null : Instant.parse(body.expiresAt())
            );
            return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(created));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        } catch (EventSanctionService.BadRequestException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        } catch (EventSanctionService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(e.getMessage()));
        } catch (EventSanctionService.ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/{eventId}/sanctions")
    public ResponseEntity<ApiResponse<List<EventSanctionDto>>> listActiveSanctions(
            HttpServletRequest request,
            @PathVariable String eventId
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized"));
        }

        try {
            return ResponseEntity.ok(ApiResponse.ok(eventSanctionService.listActive(auth.userId(), eventId)));
        } catch (EventSanctionService.ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(e.getMessage()));
        }
    }

    @PutMapping("/sanctions/{sanctionId}/revoke")
    public ResponseEntity<ApiResponse<Void>> revokeSanction(
            HttpServletRequest request,
            @PathVariable String sanctionId
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized"));
        }

        try {
            eventSanctionService.revoke(auth.userId(), sanctionId);
            return ResponseEntity.ok(ApiResponse.okMessage("Sanction revoked"));
        } catch (EventSanctionService.ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(e.getMessage()));
        }
    }

    public record CreateEventSanctionRequest(
            @NotBlank String type,
            @NotBlank String reason,
            String expiresAt
    ) {}
}

