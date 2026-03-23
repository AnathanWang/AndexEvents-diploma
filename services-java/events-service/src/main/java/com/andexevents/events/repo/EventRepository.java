package com.andexevents.events.repo;

import com.andexevents.events.model.EventDtos;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;

@Repository
public class EventRepository {
    private final JdbcTemplate jdbcTemplate;

    public EventRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String insertEvent(EventCreateParams p) {
        String id = UUID.randomUUID().toString();

        jdbcTemplate.update(
                "INSERT INTO events.\"Event\" (id, title, description, category, location, latitude, longitude, \"locationGeo\", \"dateTime\", \"endDateTime\", price, \"imageUrl\", \"isOnline\", status, \"createdById\", \"createdAt\", \"updatedAt\") " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?, ?, ?, ?, ?, 'APPROVED'::events.\"EventStatus\", ?, NOW(), NOW())",
                id,
                p.title(),
                p.description(),
                p.category(),
                p.location(),
                p.latitude(),
                p.longitude(),
                p.longitude(),
                p.latitude(),
                Timestamp.from(p.dateTime()),
                p.endDateTime() != null ? Timestamp.from(p.endDateTime()) : null,
                p.price() == null ? 0.0 : p.price(),
                p.imageUrl(),
                p.isOnline() != null && p.isOnline(),
                p.createdById()
        );

        return id;
    }

    public Optional<EventRow> findEventRowById(String id) {
        List<EventRow> rows = jdbcTemplate.query(
                "SELECT * FROM events.\"Event\" WHERE id = ?",
                (rs, rn) -> mapEventRow(rs),
                id
        );
        return rows.stream().findFirst();
    }

    public Optional<EventDtos.CreatorDto> findCreatorByEventId(String eventId) {
        List<EventDtos.CreatorDto> rows = jdbcTemplate.query(
                "SELECT u.id, u.\"displayName\", u.\"photoUrl\" FROM users.\"User\" u JOIN events.\"Event\" e ON e.\"createdById\" = u.id WHERE e.id = ?",
                (rs, rn) -> new EventDtos.CreatorDto(rs.getString("id"), rs.getString("displayName"), rs.getString("photoUrl")),
                eventId
        );
        return rows.stream().findFirst();
    }

    public long countParticipants(String eventId) {
        Long v = jdbcTemplate.queryForObject(
                "SELECT COUNT(1) FROM events.\"Participant\" WHERE \"eventId\" = ?",
                Long.class,
                eventId
        );
        return v == null ? 0 : v;
    }

    public boolean isParticipating(String eventId, String userId) {
        Integer v = jdbcTemplate.query(
                "SELECT 1 FROM events.\"Participant\" WHERE \"eventId\" = ? AND \"userId\" = ? LIMIT 1",
                rs -> rs.next() ? 1 : 0,
                eventId,
                userId
        );
        return v != null && v == 1;
    }

    public String getParticipationStatus(String eventId, String userId) {
        return jdbcTemplate.query(
                "SELECT status FROM events.\"Participant\" WHERE \"eventId\" = ? AND \"userId\" = ? LIMIT 1",
                rs -> rs.next() ? rs.getString("status") : null,
                eventId,
                userId
        );
    }

    public List<EventDtos.ParticipantDto> findTopParticipants(String eventId, int limit) {
        return jdbcTemplate.query(
                "SELECT p.id, p.\"userId\", p.\"eventId\", p.status, p.\"joinedAt\", p.\"updatedAt\", " +
                        "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, u.email as u_email " +
                        "FROM events.\"Participant\" p JOIN users.\"User\" u ON u.id = p.\"userId\" " +
                        "WHERE p.\"eventId\" = ? ORDER BY p.\"joinedAt\" DESC LIMIT ?",
                (rs, rn) -> mapParticipant(rs),
                eventId,
                limit
        );
    }

        public List<EventDtos.ParticipantDto> findParticipants(String eventId) {
        return jdbcTemplate.query(
            "SELECT p.id, p.\"userId\", p.\"eventId\", p.status, p.\"joinedAt\", p.\"updatedAt\", " +
                "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, u.email as u_email " +
                "FROM events.\"Participant\" p JOIN users.\"User\" u ON u.id = p.\"userId\" " +
                "WHERE p.\"eventId\" = ? ORDER BY p.\"joinedAt\" DESC",
            (rs, rn) -> mapParticipant(rs),
            eventId
        );
        }

    public List<EventRow> listApprovedEvents() {
        return jdbcTemplate.query(
                "SELECT * FROM events.\"Event\" WHERE status = 'APPROVED'::events.\"EventStatus\" ORDER BY \"createdAt\" DESC",
                (rs, rn) -> mapEventRow(rs)
        );
    }

    public List<EventRow> listUserApprovedEvents(String userId) {
        return jdbcTemplate.query(
                "SELECT * FROM events.\"Event\" WHERE status = 'APPROVED'::events.\"EventStatus\" AND \"createdById\" = ? ORDER BY \"createdAt\" DESC",
                (rs, rn) -> mapEventRow(rs),
                userId
        );
    }

        public List<EventRow> listUserParticipatedApprovedEvents(String userId) {
        return jdbcTemplate.query(
            "SELECT e.* FROM events.\"Event\" e " +
                "JOIN events.\"Participant\" p ON p.\"eventId\" = e.id " +
                "WHERE p.\"userId\" = ? AND e.status = 'APPROVED'::events.\"EventStatus\" " +
                "ORDER BY p.\"joinedAt\" DESC",
            (rs, rn) -> mapEventRow(rs),
            userId
        );
        }

    public NearbyQueryResult listNearbyApprovedEvents(double lat, double lon, int maxDistanceMeters, String category, int page, int limit) {
        int offset = (page - 1) * limit;

        String categoryClause = (category == null || category.isBlank()) ? "" : " AND e.category = ? ";
        List<Object> params = new ArrayList<>();
        params.add(lon);
        params.add(lat);
        params.add(maxDistanceMeters);
        if (!categoryClause.isEmpty()) {
            params.add(category);
        }
        params.add(limit);
        params.add(offset);

        String sql =
                "SELECT e.*, " +
                        "ST_Distance(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography) as distance, " +
                        "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, " +
                        "COUNT(p.id) as \"participantCount\" " +
                        "FROM events.\"Event\" e " +
                        "LEFT JOIN users.\"User\" u ON e.\"createdById\" = u.id " +
                        "LEFT JOIN events.\"Participant\" p ON e.id = p.\"eventId\" " +
                        "WHERE e.status = 'APPROVED'::events.\"EventStatus\" AND e.\"isOnline\" = false " +
                        "AND ST_DWithin(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?) " +
                        categoryClause +
                        "GROUP BY e.id, u.id " +
                        "ORDER BY distance ASC " +
                        "LIMIT ? OFFSET ?";

        // careful: we used lon/lat twice: for distance and for within
        // params currently contains only once; rebuild to match placeholders:
        List<Object> finalParams = new ArrayList<>();
        finalParams.add(lon);
        finalParams.add(lat);
        finalParams.add(lon);
        finalParams.add(lat);
        finalParams.add(maxDistanceMeters);
        if (!categoryClause.isEmpty()) {
            finalParams.add(category);
        }
        finalParams.add(limit);
        finalParams.add(offset);

        List<NearbyEventRow> events = jdbcTemplate.query(sql, nearbyRowMapper(), finalParams.toArray());

        String countSql =
                "SELECT COUNT(DISTINCT e.id) " +
                        "FROM events.\"Event\" e " +
                        "WHERE e.status = 'APPROVED'::events.\"EventStatus\" AND e.\"isOnline\" = false " +
                        "AND ST_DWithin(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?) " +
                        categoryClause;

        List<Object> countParams = new ArrayList<>();
        countParams.add(lon);
        countParams.add(lat);
        countParams.add(maxDistanceMeters);
        if (!categoryClause.isEmpty()) countParams.add(category);

        Integer total = jdbcTemplate.queryForObject(countSql, Integer.class, countParams.toArray());
        return new NearbyQueryResult(events, total == null ? 0 : total);
    }

    public Optional<EventRow> updateEvent(String eventId, EventUpdateParams p) {
        // For simplicity use update + re-read
        jdbcTemplate.update(
                "UPDATE events.\"Event\" SET title = COALESCE(?, title), description = COALESCE(?, description), category = COALESCE(?, category), " +
                        "location = COALESCE(?, location), latitude = COALESCE(?, latitude), longitude = COALESCE(?, longitude), " +
                        "\"locationGeo\" = CASE WHEN ? IS NOT NULL AND ? IS NOT NULL THEN ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography ELSE \"locationGeo\" END, " +
                        "\"dateTime\" = COALESCE(?, \"dateTime\"), \"endDateTime\" = COALESCE(?, \"endDateTime\"), price = COALESCE(?, price), \"imageUrl\" = COALESCE(?, \"imageUrl\"), \"isOnline\" = COALESCE(?, \"isOnline\"), \"updatedAt\" = NOW() " +
                        "WHERE id = ?",
                p.title(),
                p.description(),
                p.category(),
                p.location(),
                p.latitude(),
                p.longitude(),
                p.latitude(),
                p.longitude(),
                p.longitude(),
                p.latitude(),
                p.dateTime() == null ? null : Timestamp.from(p.dateTime()),
                p.endDateTime() == null ? null : Timestamp.from(p.endDateTime()),
                p.price(),
                p.imageUrl(),
                p.isOnline(),
                eventId
        );
        return findEventRowById(eventId);
    }

    public boolean deleteEvent(String eventId) {
        int affected = jdbcTemplate.update("DELETE FROM events.\"Event\" WHERE id = ?", eventId);
        return affected > 0;
    }

    public Optional<ParticipantRow> upsertParticipation(String eventId, String userId, String status) {
        String id = UUID.randomUUID().toString();
        List<ParticipantRow> rows = jdbcTemplate.query(
                "INSERT INTO events.\"Participant\" (id, \"userId\", \"eventId\", status, \"joinedAt\", \"updatedAt\") " +
                "VALUES (?, ?, ?, ?::events.\"ParticipantStatus\", NOW(), NOW()) " +
                        "ON CONFLICT (\"userId\", \"eventId\") DO UPDATE SET status = EXCLUDED.status, \"updatedAt\" = NOW() " +
                        "RETURNING id, \"userId\", \"eventId\", status, \"joinedAt\", \"updatedAt\"",
                (rs, rn) -> mapParticipantRow(rs),
                id,
                userId,
                eventId,
                status
        );
        return rows.stream().findFirst();
    }

    public Optional<ParticipantRow> deleteParticipation(String eventId, String userId) {
        List<ParticipantRow> rows = jdbcTemplate.query(
                "DELETE FROM events.\"Participant\" WHERE \"eventId\" = ? AND \"userId\" = ? RETURNING id, \"userId\", \"eventId\", status, \"joinedAt\", \"updatedAt\"",
                (rs, rn) -> mapParticipantRow(rs),
                eventId,
                userId
        );
        return rows.stream().findFirst();
    }

    public record EventCreateParams(
            String title,
            String description,
            String category,
            String location,
            double latitude,
            double longitude,
            Instant dateTime,
            Instant endDateTime,
            Double price,
            String imageUrl,
            Boolean isOnline,
            String createdById
    ) {
    }

    public record EventUpdateParams(
            String title,
            String description,
            String category,
            String location,
            Double latitude,
            Double longitude,
            Instant dateTime,
            Instant endDateTime,
            Double price,
            String imageUrl,
            Boolean isOnline
    ) {
    }

    public record EventRow(
            String id,
            String title,
            String description,
            String category,
            String location,
            double latitude,
            double longitude,
            Instant dateTime,
            Instant endDateTime,
            double price,
            String imageUrl,
            boolean isOnline,
            String status,
            String rejectionReason,
            Integer maxParticipants,
            Integer minAge,
            Integer maxAge,
            String createdById,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record NearbyEventRow(EventRow event, double distance, EventDtos.CreatorDto createdBy, long participantCount) {
    }

    public record NearbyQueryResult(List<NearbyEventRow> events, int total) {
    }

    public record ParticipantRow(String id, String userId, String eventId, String status, Instant joinedAt, Instant updatedAt) {
    }

    private EventRow mapEventRow(ResultSet rs) throws SQLException {
        return new EventRow(
                rs.getString("id"),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("category"),
                rs.getString("location"),
                rs.getDouble("latitude"),
                rs.getDouble("longitude"),
                toInstant(rs.getObject("dateTime")),
                toInstant(rs.getObject("endDateTime")),
                rs.getDouble("price"),
                rs.getString("imageUrl"),
                rs.getBoolean("isOnline"),
                rs.getString("status"),
                rs.getString("rejectionReason"),
                (Integer) rs.getObject("maxParticipants"),
                (Integer) rs.getObject("minAge"),
                (Integer) rs.getObject("maxAge"),
                rs.getString("createdById"),
                toInstant(rs.getObject("createdAt")),
                toInstant(rs.getObject("updatedAt"))
        );
    }

    private RowMapper<NearbyEventRow> nearbyRowMapper() {
        return (rs, rn) -> {
            EventRow event = mapEventRow(rs);
            double distance = rs.getDouble("distance");
            long participantCount = rs.getLong("participantCount");
            EventDtos.CreatorDto createdBy = null;
            String creatorId = rs.getString("u_id");
            if (creatorId != null) {
                createdBy = new EventDtos.CreatorDto(creatorId, rs.getString("u_displayName"), rs.getString("u_photoUrl"));
            }
            return new NearbyEventRow(event, distance, createdBy, participantCount);
        };
    }

    private EventDtos.ParticipantDto mapParticipant(ResultSet rs) throws SQLException {
        EventDtos.UserPreviewDto u = new EventDtos.UserPreviewDto(
                rs.getString("u_id"),
                rs.getString("u_displayName"),
                rs.getString("u_photoUrl"),
                rs.getString("u_email")
        );

        return new EventDtos.ParticipantDto(
                rs.getString("id"),
                rs.getString("userId"),
                rs.getString("eventId"),
                rs.getString("status"),
                toInstant(rs.getObject("joinedAt")),
                toInstant(rs.getObject("updatedAt")),
                u
        );
    }

    private ParticipantRow mapParticipantRow(ResultSet rs) throws SQLException {
        return new ParticipantRow(
                rs.getString("id"),
                rs.getString("userId"),
                rs.getString("eventId"),
                rs.getString("status"),
                toInstant(rs.getObject("joinedAt")),
                toInstant(rs.getObject("updatedAt"))
        );
    }

    private Instant toInstant(Object ts) {
        if (ts == null) return null;
        if (ts instanceof java.sql.Timestamp t) return t.toInstant();
        if (ts instanceof java.time.OffsetDateTime odt) return odt.toInstant();
        if (ts instanceof java.time.LocalDateTime ldt) return ldt.atZone(java.time.ZoneOffset.UTC).toInstant();
        return null;
    }
}
