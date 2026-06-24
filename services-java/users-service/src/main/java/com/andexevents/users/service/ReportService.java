package com.andexevents.users.service;

import com.andexevents.users.model.ReportDto;
import com.andexevents.users.model.ReportReason;
import com.andexevents.users.repo.ReportRepository;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.Optional;

@Service
public class ReportService {
    private final ReportRepository reportRepository;

    public ReportService(ReportRepository reportRepository) {
        this.reportRepository = reportRepository;
    }

    public ReportDto createReport(String reporterId, String targetUserId,
                                   String targetEventId, String reason, String details) {
        ReportReason reportReason;
        try {
            reportReason = ReportReason.valueOf(reason);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid report reason: " + reason);
        }

        boolean hasUserTarget = targetUserId != null && !targetUserId.isBlank();
        boolean hasEventTarget = targetEventId != null && !targetEventId.isBlank();
        if (!hasUserTarget && !hasEventTarget) {
            throw new IllegalArgumentException("Report must target a user or an event");
        }

        if (hasUserTarget && !isUserReason(reportReason)) {
            throw new IllegalArgumentException("Invalid reason for user report: " + reportReason);
        }

        if (hasEventTarget && !isEventReason(reportReason)) {
            throw new IllegalArgumentException("Invalid reason for event report: " + reportReason);
        }

        return reportRepository.insert(reporterId, targetUserId, targetEventId, reportReason, details);
    }

    private boolean isUserReason(ReportReason r) {
        return switch (r) {
            case SPAM_PROFILE, FAKE_PROFILE, HARASSMENT, INAPPROPRIATE_PHOTOS, SCAM, OTHER -> true;
            default -> false;
        };
    }

    private boolean isEventReason(ReportReason r) {
        return switch (r) {
            case SPAM, INAPPROPRIATE_CONTENT, HARASSMENT, FAKE_EVENT, OTHER -> true;
            default -> false;
        };
    }

    public List<ReportDto> getAllReports() {
        return reportRepository.findAll();
    }

    public List<Map<String, Object>> getAllReportsEnriched() {
        try {
            return reportRepository.findAllEnriched().stream().map(row -> {
                Map<String, Object> report = new HashMap<>();
                report.put("id", row.get("id"));
                report.put("reporterId", row.get("reporterId"));
                report.put("targetUserId", row.get("targetUserId"));
                report.put("targetEventId", row.get("targetEventId"));
                report.put("reason", row.get("reason"));
                report.put("details", row.get("details"));
                report.put("status", row.get("status"));
                report.put("resolverId", row.get("resolverId"));
                report.put("resolvedAt", row.get("resolvedAt"));
                report.put("createdAt", row.get("createdAt"));
                report.put("updatedAt", row.get("updatedAt"));

                Map<String, Object> reporter = null;
                if (row.get("reporter_user_id") != null) {
                    reporter = new HashMap<>();
                    reporter.put("id", row.get("reporter_user_id"));
                    reporter.put("displayName", row.get("reporter_display_name"));
                    reporter.put("email", row.get("reporter_email"));
                    reporter.put("photoUrl", row.get("reporter_photo_url"));
                }

                Map<String, Object> targetUser = null;
                if (row.get("target_user_id2") != null) {
                    targetUser = new HashMap<>();
                    targetUser.put("id", row.get("target_user_id2"));
                    targetUser.put("displayName", row.get("target_display_name"));
                    targetUser.put("email", row.get("target_email"));
                    targetUser.put("photoUrl", row.get("target_photo_url"));
                }

                Map<String, Object> targetEvent = null;
                if (row.get("target_event_id2") != null) {
                    targetEvent = new HashMap<>();
                    targetEvent.put("id", row.get("target_event_id2"));
                    targetEvent.put("title", row.get("target_event_title"));
                    targetEvent.put("imageUrl", row.get("target_event_image_url"));
                }

                Map<String, Object> out = new HashMap<>();
                out.put("report", report);
                out.put("reporter", reporter);
                out.put("targetUser", targetUser);
                out.put("targetEvent", targetEvent);
                return out;
            }).toList();
        } catch (Exception e) {
            // events schema may be absent in isolated setups; fallback to plain list
            return reportRepository.findAll().stream().map(r -> {
                Map<String, Object> report = new HashMap<>();
                report.put("id", r.id());
                report.put("reporterId", r.reporterId());
                report.put("targetUserId", r.targetUserId());
                report.put("targetEventId", r.targetEventId());
                report.put("reason", r.reason() == null ? null : r.reason().name());
                report.put("details", r.details());
                report.put("status", r.status() == null ? null : r.status().name());
                report.put("resolverId", r.resolverId());
                report.put("resolvedAt", r.resolvedAt());
                report.put("createdAt", r.createdAt());
                report.put("updatedAt", r.updatedAt());

                Map<String, Object> out = new HashMap<>();
                out.put("report", report);
                out.put("reporter", null);
                out.put("targetUser", null);
                out.put("targetEvent", null);
                return out;
            }).toList();
        }
    }

    public Optional<ReportDto> getReportById(String id) {
        return reportRepository.findById(id);
    }

    public void resolveReport(String reportId, String resolverId, String resolution) {
        Optional<ReportDto> existing = reportRepository.findById(reportId);
        if (existing.isEmpty()) {
            throw new NotFoundException("Report not found: " + reportId);
        }

        String status = switch (resolution.toUpperCase()) {
            case "RESOLVED", "RESOLVE" -> "RESOLVED";
            case "DISMISSED", "DISMISS" -> "DISMISSED";
            default -> "RESOLVED";
        };

        reportRepository.resolve(reportId, resolverId, status);
    }

    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) {
            super(message);
        }
    }
}
