package com.andexevents.events.repo;

import com.andexevents.events.model.EventDtos;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public class OrganizerBlockRepository {
    private final JdbcTemplate jdbcTemplate;

    public OrganizerBlockRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean isBlocked(String organizerUserId, String blockedUserId) {
        Integer v = jdbcTemplate.query(
                "SELECT 1 FROM events.\"OrganizerBlock\" WHERE \"organizerUserId\" = ? AND \"blockedUserId\" = ? LIMIT 1",
                rs -> rs.next() ? 1 : 0,
                organizerUserId,
                blockedUserId
        );
        return v != null && v == 1;
    }

    public void upsertBlock(String organizerUserId, String blockedUserId, String reason) {
        String id = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO events.\"OrganizerBlock\" (id, \"organizerUserId\", \"blockedUserId\", reason, \"createdAt\") " +
                        "VALUES (?, ?, ?, ?, NOW()) " +
                        "ON CONFLICT (\"organizerUserId\", \"blockedUserId\") DO UPDATE SET reason = EXCLUDED.reason, \"createdAt\" = NOW()",
                id,
                organizerUserId,
                blockedUserId,
                reason
        );
    }

    public void deleteBlock(String organizerUserId, String blockedUserId) {
        jdbcTemplate.update(
                "DELETE FROM events.\"OrganizerBlock\" WHERE \"organizerUserId\" = ? AND \"blockedUserId\" = ?",
                organizerUserId,
                blockedUserId
        );
    }

    public List<EventDtos.UserPreviewDto> listBlockedUsers(String organizerUserId) {
        return jdbcTemplate.query(
                "SELECT u.id, u.\"displayName\", u.\"photoUrl\", u.email " +
                        "FROM events.\"OrganizerBlock\" b JOIN users.\"User\" u ON u.id = b.\"blockedUserId\" " +
                        "WHERE b.\"organizerUserId\" = ? ORDER BY b.\"createdAt\" DESC",
                (rs, rn) -> new EventDtos.UserPreviewDto(
                        rs.getString("id"),
                        rs.getString("displayName"),
                        rs.getString("photoUrl"),
                        rs.getString("email")
                ),
                organizerUserId
        );
    }
}

