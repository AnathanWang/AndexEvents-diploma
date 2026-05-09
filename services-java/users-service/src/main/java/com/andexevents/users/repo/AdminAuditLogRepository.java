package com.andexevents.users.repo;

import com.andexevents.users.model.AdminAuditLogDto;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Repository
public class AdminAuditLogRepository {
    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public AdminAuditLogRepository(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public void insert(String actorUserId, String targetUserId, String action, Map<String, Object> details) {
        String id = UUID.randomUUID().toString();
        String detailsJson = "{}";
        try {
            if (details != null) {
                detailsJson = objectMapper.writeValueAsString(details);
            }
        } catch (Exception ignored) {
            detailsJson = "{}";
        }

        jdbcTemplate.update(
                """
                INSERT INTO users."AdminAuditLog" ("id", "actorUserId", "targetUserId", "action", "details", "createdAt")
                VALUES (?, ?, ?, ?, CAST(? AS jsonb), NOW())
                """,
                id,
                actorUserId,
                targetUserId,
                action,
                detailsJson
        );
    }

    public List<AdminAuditLogDto> findRecent(int limit) {
        int effectiveLimit = Math.max(1, Math.min(limit, 500));
        return jdbcTemplate.query(
                """
                SELECT *
                FROM users."AdminAuditLog"
                ORDER BY "createdAt" DESC
                LIMIT ?
                """,
                (rs, rowNum) -> mapRow(rs),
                effectiveLimit
        );
    }

    private AdminAuditLogDto mapRow(ResultSet rs) throws SQLException {
        Map<String, Object> detailsMap = new HashMap<>();
        String detailsRaw = rs.getString("details");
        if (detailsRaw != null && !detailsRaw.isBlank()) {
            try {
                detailsMap = objectMapper.readValue(detailsRaw, new TypeReference<>() {});
            } catch (Exception ignored) {
                detailsMap = new HashMap<>();
            }
        }

        return new AdminAuditLogDto(
                rs.getString("id"),
                rs.getString("actorUserId"),
                rs.getString("targetUserId"),
                rs.getString("action"),
                detailsMap,
                rs.getTimestamp("createdAt").toInstant()
        );
    }
}
