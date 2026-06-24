package com.andexevents.users.repo;

import com.andexevents.users.model.ReportDto;
import com.andexevents.users.model.ReportReason;
import com.andexevents.users.model.ReportStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.Map;

@Repository
public class ReportRepository {
    private final JdbcTemplate jdbcTemplate;

    public ReportRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public ReportDto insert(String reporterId, String targetUserId, String targetEventId,
                            ReportReason reason, String details) {
        String id = UUID.randomUUID().toString();
        Instant now = Instant.now();

        jdbcTemplate.update(
                """
                INSERT INTO users."Report" ("id", "reporterId", "targetUserId", "targetEventId",
                    "reason", "details", "status", "createdAt", "updatedAt")
                VALUES (?, ?, ?, ?, ?::users."ReportReason", ?, 'PENDING'::users."ReportStatus", ?, ?)
                """,
                id, reporterId, targetUserId, targetEventId,
                reason.name(), details,
                Timestamp.from(now), Timestamp.from(now)
        );

        return new ReportDto(id, reporterId, targetUserId, targetEventId,
                reason, details, ReportStatus.PENDING, null, null, now, now);
    }

    public List<ReportDto> findAll() {
        return jdbcTemplate.query(
                """
                SELECT * FROM users."Report" ORDER BY "createdAt" DESC
                """,
                mapper()
        );
    }

    public List<Map<String, Object>> findAllEnriched() {
        return jdbcTemplate.queryForList(
                """
                SELECT
                  r.*,
                  ru.id          AS reporter_user_id,
                  ru."displayName" AS reporter_display_name,
                  ru.email       AS reporter_email,
                  ru."photoUrl"  AS reporter_photo_url,
                  tu.id          AS target_user_id2,
                  tu."displayName" AS target_display_name,
                  tu.email       AS target_email,
                  tu."photoUrl"  AS target_photo_url,
                  e.id           AS target_event_id2,
                  e.title        AS target_event_title,
                  e."imageUrl"   AS target_event_image_url
                FROM users."Report" r
                LEFT JOIN users."User" ru ON ru.id = r."reporterId"
                LEFT JOIN users."User" tu ON tu.id = r."targetUserId"
                LEFT JOIN events."Event" e ON e.id = r."targetEventId"
                ORDER BY r."createdAt" DESC
                """
        );
    }

    public Optional<ReportDto> findById(String id) {
        List<ReportDto> rows = jdbcTemplate.query(
                """
                SELECT * FROM users."Report" WHERE "id" = ?
                """,
                mapper(),
                id
        );
        return rows.stream().findFirst();
    }

    public List<ReportDto> findByReporterId(String reporterId) {
        return jdbcTemplate.query(
                """
                SELECT * FROM users."Report" WHERE "reporterId" = ? ORDER BY "createdAt" DESC
                """,
                mapper(),
                reporterId
        );
    }

    public void resolve(String reportId, String resolverId, String status) {
        jdbcTemplate.update(
                """
                UPDATE users."Report"
            SET "status" = ?::users."ReportStatus", "resolverId" = ?, "resolvedAt" = NOW(), "updatedAt" = NOW()
                WHERE "id" = ?
                """,
                status, resolverId, reportId
        );
    }

    private @NonNull RowMapper<ReportDto> mapper() {
        return (ResultSet rs, int rowNum) -> mapRow(rs);
    }

    private ReportDto mapRow(ResultSet rs) throws SQLException {
        return new ReportDto(
                rs.getString("id"),
                rs.getString("reporterId"),
                rs.getString("targetUserId"),
                rs.getString("targetEventId"),
                ReportReason.valueOf(rs.getString("reason")),
                rs.getString("details"),
                ReportStatus.valueOf(rs.getString("status")),
                rs.getString("resolverId"),
                rs.getTimestamp("resolvedAt") != null ? rs.getTimestamp("resolvedAt").toInstant() : null,
                rs.getTimestamp("createdAt").toInstant(),
                rs.getTimestamp("updatedAt").toInstant()
        );
    }
}
