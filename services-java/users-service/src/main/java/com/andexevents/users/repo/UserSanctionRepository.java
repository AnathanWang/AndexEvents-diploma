package com.andexevents.users.repo;

import com.andexevents.users.model.UserSanctionDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class UserSanctionRepository {
    private final JdbcTemplate jdbcTemplate;

    public UserSanctionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public UserSanctionDto insert(
            String targetUserId,
            String createdByUserId,
            String type,
            String reason,
            Instant expiresAt
    ) {
        String id = UUID.randomUUID().toString();

        jdbcTemplate.update(
                """
                INSERT INTO users."UserSanction"
                    ("id", "targetUserId", "createdByUserId", "type", "reason", "expiresAt", "createdAt", "updatedAt")
                VALUES (?, ?, ?, CAST(? AS users."UserSanctionType"), ?, ?, NOW(), NOW())
                """,
                id,
                targetUserId,
                createdByUserId,
                type,
                reason,
                expiresAt == null ? null : Timestamp.from(expiresAt)
        );

        return findById(id).orElseThrow();
    }

    public Optional<UserSanctionDto> findById(String id) {
        List<UserSanctionDto> rows = jdbcTemplate.query(
                """
                SELECT *
                FROM users."UserSanction"
                WHERE "id" = ?
                """,
                (rs, rowNum) -> mapRow(rs),
                id
        );
        return rows.stream().findFirst();
    }

    public List<UserSanctionDto> findByTargetUserId(String targetUserId) {
        return jdbcTemplate.query(
                """
                SELECT *
                FROM users."UserSanction"
                WHERE "targetUserId" = ?
                ORDER BY "createdAt" DESC
                """,
                (rs, rowNum) -> mapRow(rs),
                targetUserId
        );
    }

    public List<UserSanctionDto> findActiveAll(int limit) {
        int effectiveLimit = Math.max(1, Math.min(limit, 1000));
        return jdbcTemplate.query(
                """
                SELECT *
                FROM users."UserSanction"
                WHERE "revokedAt" IS NULL
                  AND ("expiresAt" IS NULL OR "expiresAt" > NOW())
                ORDER BY "createdAt" DESC
                LIMIT ?
                """,
                (rs, rowNum) -> mapRow(rs),
                effectiveLimit
        );
    }

    public void revoke(String sanctionId, String revokedByUserId) {
        jdbcTemplate.update(
                """
                UPDATE users."UserSanction"
                SET "revokedAt" = NOW(), "revokedByUserId" = ?, "updatedAt" = NOW()
                WHERE "id" = ?
                  AND "revokedAt" IS NULL
                """,
                revokedByUserId,
                sanctionId
        );
    }

    private UserSanctionDto mapRow(ResultSet rs) throws SQLException {
        Timestamp expiresAt = rs.getTimestamp("expiresAt");
        Timestamp revokedAt = rs.getTimestamp("revokedAt");

        return new UserSanctionDto(
                rs.getString("id"),
                rs.getString("targetUserId"),
                rs.getString("createdByUserId"),
                rs.getString("type"),
                rs.getString("reason"),
                expiresAt == null ? null : expiresAt.toInstant(),
                revokedAt == null ? null : revokedAt.toInstant(),
                rs.getString("revokedByUserId"),
                rs.getTimestamp("createdAt").toInstant(),
                rs.getTimestamp("updatedAt").toInstant()
        );
    }
}
