package com.andexevents.events.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EventReportReadRepository {
    private final JdbcTemplate jdbcTemplate;

    public EventReportReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean hasPendingEventReports(String eventId) {
        Boolean exists = jdbcTemplate.queryForObject(
                """
                SELECT EXISTS(
                  SELECT 1
                  FROM users."Report" r
                  WHERE r."targetEventId" = ?
                    AND r."status" = 'PENDING'::users."ReportStatus"
                )
                """,
                Boolean.class,
                eventId
        );
        return exists != null && exists;
    }
}

