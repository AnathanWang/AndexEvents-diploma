package com.andexevents.events.repo;

import com.andexevents.events.model.EventDtos;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public class EventParticipantBanRepository {
    private final JdbcTemplate jdbcTemplate;

    public EventParticipantBanRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean isBanned(String eventId, String userId) {
        Integer v = jdbcTemplate.query(
                "SELECT 1 FROM events.\"EventParticipantBan\" WHERE \"eventId\" = ? AND \"userId\" = ? LIMIT 1",
                rs -> rs.next() ? 1 : 0,
                eventId,
                userId
        );
        return v != null && v == 1;
    }

    public void upsertBan(String eventId, String userId, String reason, String createdById) {
        String id = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO events.\"EventParticipantBan\" (id, \"eventId\", \"userId\", reason, \"createdById\", \"createdAt\") " +
                        "VALUES (?, ?, ?, ?, ?, NOW()) " +
                        "ON CONFLICT (\"eventId\", \"userId\") DO UPDATE SET reason = EXCLUDED.reason, \"createdById\" = EXCLUDED.\"createdById\", \"createdAt\" = NOW()",
                id,
                eventId,
                userId,
                reason,
                createdById
        );
    }

    public void deleteBan(String eventId, String userId) {
        jdbcTemplate.update(
                "DELETE FROM events.\"EventParticipantBan\" WHERE \"eventId\" = ? AND \"userId\" = ?",
                eventId,
                userId
        );
    }

    public List<EventDtos.UserPreviewDto> listBannedUsersForEvent(String eventId) {
        return jdbcTemplate.query(
                "SELECT u.id, u.\"displayName\", u.\"photoUrl\", u.email " +
                        "FROM events.\"EventParticipantBan\" b " +
                        "JOIN users.\"User\" u ON u.id = b.\"userId\" " +
                        "WHERE b.\"eventId\" = ? ORDER BY b.\"createdAt\" DESC",
                (rs, rn) -> new EventDtos.UserPreviewDto(
                        rs.getString("id"),
                        rs.getString("displayName"),
                        rs.getString("photoUrl"),
                        rs.getString("email")
                ),
                eventId
        );
    }
}

