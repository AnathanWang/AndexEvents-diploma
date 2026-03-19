package com.andexevents.users.controller;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.auth.AuthContext;
import com.andexevents.users.auth.AuthFilter;
import com.andexevents.users.model.ReportDto;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.service.ReportService;
import com.andexevents.users.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users/reports")
public class ReportController {
    private final ReportService reportService;
    private final UserService userService;

    public ReportController(ReportService reportService, UserService userService) {
        this.reportService = reportService;
        this.userService = userService;
    }

    /**
     * POST /api/users/reports — submit a new report
     */
    @PostMapping
    public ResponseEntity<ApiResponse<ReportDto>> submitReport(
            HttpServletRequest request,
            @RequestBody CreateReportRequest body
    ) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        if (body.reason() == null || body.reason().isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("Report reason is required"));
        }

        try {
            ReportDto report = reportService.createReport(
                    body.reporterId() != null ? body.reporterId() : auth.userId(),
                    body.targetUserId(),
                    body.targetEventId(),
                    body.reason(),
                    body.details()
            );
            return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(report));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        }
    }

    /**
     * GET /api/users/reports — get all reports (admin)
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<ReportDto>>> getReports(HttpServletRequest request) {
        UserDto requester = resolveRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        if (!isAdmin(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: admin access required"));
        }

        List<ReportDto> reports = reportService.getAllReports();
        return ResponseEntity.ok(ApiResponse.ok(reports));
    }

    /**
     * GET /api/users/reports/events — get only event reports (admin/moderator)
     */
    @GetMapping("/events")
    public ResponseEntity<ApiResponse<List<ReportDto>>> getEventReports(HttpServletRequest request) {
        UserDto requester = resolveRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        if (!userService.canModerate(requester)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: moderation access required"));
        }

        List<ReportDto> eventReports = reportService.getAllReports().stream()
                .filter(report -> report.targetEventId() != null && !report.targetEventId().isBlank())
                .toList();

        return ResponseEntity.ok(ApiResponse.ok(eventReports));
    }

    /**
     * PUT /api/users/reports/{reportId} — resolve a report (admin)
     */
    @PutMapping("/{reportId}")
    public ResponseEntity<ApiResponse<Void>> resolveReport(
            HttpServletRequest request,
            @PathVariable String reportId,
            @RequestBody Map<String, String> body
    ) {
        UserDto requester = resolveRequester(request);
        if (requester == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        var report = reportService.getReportById(reportId).orElse(null);
        if (report == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("Report not found: " + reportId));
        }

        boolean canResolve = isAdmin(requester)
                || (userService.canModerate(requester)
                && report.targetEventId() != null
                && !report.targetEventId().isBlank());

        if (!canResolve) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Forbidden: moderation access required"));
        }

        String resolution = body.getOrDefault("resolution", "RESOLVED");

        try {
            reportService.resolveReport(reportId, requester.id(), resolution);
            return ResponseEntity.ok(ApiResponse.okMessage("Report resolved"));
        } catch (ReportService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        }
    }

    private UserDto resolveRequester(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return null;
        }

        return userService.getById(auth.userId()).orElse(null);
    }

    private boolean isAdmin(UserDto user) {
        return user != null
                && user.role() != null
                && "ADMIN".equalsIgnoreCase(user.role().trim());
    }

    public record CreateReportRequest(
            String reporterId,
            String targetUserId,
            String targetEventId,
            String reason,
            String details
    ) {}
}
