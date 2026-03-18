package com.andexevents.users.service;

import com.andexevents.users.model.ReportDto;
import com.andexevents.users.model.ReportReason;
import com.andexevents.users.repo.ReportRepository;
import org.springframework.stereotype.Service;

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
            throw new IllegalArgumentException("Invalid report reason: " + reason +
                    ". Allowed values: SPAM, INAPPROPRIATE_CONTENT, HARASSMENT, FAKE_EVENT, OTHER");
        }

        return reportRepository.insert(reporterId, targetUserId, targetEventId, reportReason, details);
    }

    public List<ReportDto> getAllReports() {
        return reportRepository.findAll();
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
