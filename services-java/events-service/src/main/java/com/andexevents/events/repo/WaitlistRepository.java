package com.andexevents.events.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import com.andexevents.events.model.EventDtos;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public class WaitlistRepository {
    private final JdbcTemplate jdbcTemplate;

    public WaitlistRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public record WaitlistEntryRow(
            String id,
            String eventId,
            String userId,
            String status,
            Instant createdAt,
            Instant updatedAt,
            EventDtos.UserPreviewDto user
    ) {
    }

    public void upsertPending(String eventId, String userId) {
        String id = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO events.\"WaitlistEntry\" (id, \"eventId\", \"userId\", status, \"createdAt\", \"updatedAt\") " +
                        "VALUES (?, ?, ?, 'PENDING'::events.\"WaitlistStatus\", NOW(), NOW()) " +
                        "ON CONFLICT (\"eventId\", \"userId\") DO UPDATE SET status = 'PENDING'::events.\"WaitlistStatus\", \"updatedAt\" = NOW()",
                id,
                eventId,
                userId
        );
    }

    public List<WaitlistEntryRow> listByEvent(String eventId) {
        return jdbcTemplate.query(
                "SELECT w.id, w.\"eventId\", w.\"userId\", w.status, w.\"createdAt\", w.\"updatedAt\", " +
                        "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, u.email as u_email " +
                        "FROM events.\"WaitlistEntry\" w JOIN users.\"User\" u ON u.id = w.\"userId\" " +
                        "WHERE w.\"eventId\" = ? ORDER BY w.\"createdAt\" DESC",
                (rs, rn) -> mapRow(rs),
                eventId
        );
    }

    public void approve(String eventId, String userId) {
        jdbcTemplate.update(
                "UPDATE events.\"WaitlistEntry\" SET status = 'APPROVED'::events.\"WaitlistStatus\", \"updatedAt\" = NOW() WHERE \"eventId\" = ? AND \"userId\" = ?",
                eventId,
                userId
        );
    }

    public void reject(String eventId, String userId) {
        jdbcTemplate.update(
                "UPDATE events.\"WaitlistEntry\" SET status = 'REJECTED'::events.\"WaitlistStatus\", \"updatedAt\" = NOW() WHERE \"eventId\" = ? AND \"userId\" = ?",
                eventId,
                userId
        );
    }

    private WaitlistEntryRow mapRow(ResultSet rs) throws SQLException {
        return new WaitlistEntryRow(
                rs.getString("id"),
                rs.getString("eventId"),
                rs.getString("userId"),
                rs.getString("status"),
                rs.getTimestamp("createdAt").toInstant(),
                rs.getTimestamp("updatedAt").toInstant(),
                new EventDtos.UserPreviewDto(
                        rs.getString("u_id"),
                        rs.getString("u_displayName"),
                        rs.getString("u_photoUrl"),
                        rs.getString("u_email")
                )
        );
    }
}

