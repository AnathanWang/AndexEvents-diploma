package com.andexevents.users.controller;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.auth.AuthContext;
import com.andexevents.users.auth.AuthFilter;
import com.andexevents.users.model.ReportDto;
import com.andexevents.users.service.ReportService;
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

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
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
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        List<ReportDto> reports = reportService.getAllReports();
        return ResponseEntity.ok(ApiResponse.ok(reports));
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
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.userId() == null || auth.userId().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: User ID not found"));
        }

        String resolution = body.getOrDefault("resolution", "RESOLVED");

        try {
            reportService.resolveReport(reportId, auth.userId(), resolution);
            return ResponseEntity.ok(ApiResponse.okMessage("Report resolved"));
        } catch (ReportService.NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        }
    }

    public record CreateReportRequest(
            String reporterId,
            String targetUserId,
            String targetEventId,
            String reason,
            String details
    ) {}
}
