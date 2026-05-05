package com.andexevents.events.repo;

import com.andexevents.events.model.EventSanctionDto;
import com.andexevents.events.model.EventSanctionType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class EventSanctionRepository {
    private final JdbcTemplate jdbcTemplate;

    public EventSanctionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public EventSanctionDto create(
            String eventId,
            EventSanctionType type,
            String reason,
            Instant expiresAt,
            String createdById
    ) {
        String id = UUID.randomUUID().toString();

        jdbcTemplate.update(
                """
                INSERT INTO events."EventSanction"(
                  "id","eventId","type","reason","createdById","expiresAt","createdAt","updatedAt"
                )
                VALUES (
                  ?, ?, ?::events."EventSanctionType", ?, ?, ?, NOW(), NOW()
                )
                """,
                id,
                eventId,
                type.name(),
                reason,
                createdById,
                expiresAt == null ? null : java.sql.Timestamp.from(expiresAt)
        );

        return findById(id).orElseThrow();
    }

    public Optional<EventSanctionDto> findById(String id) {
        List<EventSanctionDto> rows = jdbcTemplate.query(
                """
                SELECT * FROM events."EventSanction" WHERE "id" = ?
                """,
                mapper(),
                id
        );
        return rows.stream().findFirst();
    }

    public List<EventSanctionDto> listActiveByEventId(String eventId) {
        return jdbcTemplate.query(
                """
                SELECT * FROM events."EventSanction"
                WHERE "eventId" = ?
                  AND "revokedAt" IS NULL
                  AND ("expiresAt" IS NULL OR "expiresAt" > NOW())
                ORDER BY "createdAt" DESC
                """,
                mapper(),
                eventId
        );
    }

    public boolean hasActive(String eventId, EventSanctionType type) {
        Boolean exists = jdbcTemplate.queryForObject(
                """
                SELECT EXISTS(
                  SELECT 1
                  FROM events."EventSanction"
                  WHERE "eventId" = ?
                    AND "type" = ?::events."EventSanctionType"
                    AND "revokedAt" IS NULL
                    AND ("expiresAt" IS NULL OR "expiresAt" > NOW())
                )
                """,
                Boolean.class,
                eventId,
                type.name()
        );
        return exists != null && exists;
    }

    public void revoke(String sanctionId, String revokedById) {
        jdbcTemplate.update(
                """
                UPDATE events."EventSanction"
                SET "revokedAt" = NOW(),
                    "revokedById" = ?,
                    "updatedAt" = NOW()
                WHERE "id" = ?
                """,
                revokedById,
                sanctionId
        );
    }

    private @NonNull RowMapper<EventSanctionDto> mapper() {
        return (ResultSet rs, int rowNum) -> mapRow(rs);
    }

    private EventSanctionDto mapRow(ResultSet rs) throws SQLException {
        return new EventSanctionDto(
                rs.getString("id"),
                rs.getString("eventId"),
                EventSanctionType.valueOf(rs.getString("type")),
                rs.getString("reason"),
                rs.getString("createdById"),
                rs.getTimestamp("expiresAt") != null ? rs.getTimestamp("expiresAt").toInstant() : null,
                rs.getTimestamp("revokedAt") != null ? rs.getTimestamp("revokedAt").toInstant() : null,
                rs.getString("revokedById"),
                rs.getTimestamp("createdAt").toInstant(),
                rs.getTimestamp("updatedAt").toInstant()
        );
    }
}

