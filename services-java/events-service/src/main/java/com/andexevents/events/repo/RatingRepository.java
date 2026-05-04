package com.andexevents.events.repo;

import com.andexevents.events.model.EventDtos;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public class RatingRepository {

    private final JdbcTemplate jdbcTemplate;

    public RatingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Insert or update a rating. Returns the saved RatingDto.
     */
    public EventDtos.RatingDto upsertRating(String eventId, String userId, int rating, String comment) {
        String id = UUID.randomUUID().toString();
        List<EventDtos.RatingDto> rows = jdbcTemplate.query(
                "INSERT INTO events.\"EventRating\" (id, \"eventId\", \"userId\", rating, comment, \"createdAt\", \"updatedAt\") " +
                "VALUES (?, ?, ?, ?, ?, NOW(), NOW()) " +
                "ON CONFLICT (\"userId\", \"eventId\") DO UPDATE " +
                "  SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, \"updatedAt\" = NOW() " +
                "RETURNING id, \"userId\", \"eventId\", rating, comment, \"createdAt\"",
                (rs, rn) -> mapRating(rs),
                id, eventId, userId, rating, comment
        );
        return rows.stream().findFirst().orElseThrow();
    }

    /**
     * Get average rating, count, and current user's rating for an event.
     */
    public EventDtos.EventRatingStatsDto findStats(String eventId, String viewerUserId) {
        return jdbcTemplate.query(
                "SELECT " +
                "  COALESCE(AVG(rating), 0) AS avg_rating, " +
                "  COUNT(*) AS rating_count, " +
                "  MAX(CASE WHEN \"userId\" = ? THEN rating END) AS my_rating " +
                "FROM events.\"EventRating\" WHERE \"eventId\" = ?",
                rs -> {
                    if (!rs.next()) return new EventDtos.EventRatingStatsDto(0.0, 0, null);
                    double avg = rs.getDouble("avg_rating");
                    long count = rs.getLong("rating_count");
                    Integer myRating = (Integer) rs.getObject("my_rating");
                    return new EventDtos.EventRatingStatsDto(avg, count, myRating);
                },
                viewerUserId != null ? viewerUserId : "",
                eventId
        );
    }

    /**
     * Count how many APPROVED events this user has created.
     */
    public long countUserApprovedEvents(String userId) {
        Long v = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM events.\"Event\" WHERE \"createdById\" = ? AND status = 'APPROVED'::events.\"EventStatus\"",
                Long.class, userId
        );
        return v == null ? 0 : v;
    }

    /**
     * Calculate average rating of all events created by this user.
     * Returns null if user has fewer than 3 approved events.
     */
    public EventDtos.UserRatingDto findUserRating(String userId) {
        long eventCount = countUserApprovedEvents(userId);
        if (eventCount < 3) return null;

        return jdbcTemplate.query(
                "SELECT COALESCE(AVG(r.rating), 0) AS avg_rating, ? AS events_count " +
                "FROM events.\"Event\" e " +
                "LEFT JOIN events.\"EventRating\" r ON r.\"eventId\" = e.id " +
                "WHERE e.\"createdById\" = ? AND e.status = 'APPROVED'::events.\"EventStatus\"",
                rs -> {
                    if (!rs.next()) return new EventDtos.UserRatingDto(0.0, eventCount);
                    return new EventDtos.UserRatingDto(rs.getDouble("avg_rating"), eventCount);
                },
                eventCount, userId
        );
    }

    /**
     * List rating reviews for an event with reviewer info.
     */
    public List<EventDtos.RatingReviewDto> findReviews(String eventId) {
        return jdbcTemplate.query(
                "SELECT r.id, r.\"userId\", r.\"eventId\", r.rating, r.comment, r.\"createdAt\", " +
                "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, u.email as u_email " +
                "FROM events.\"EventRating\" r " +
                "JOIN users.\"User\" u ON u.id = r.\"userId\" " +
                "WHERE r.\"eventId\" = ? " +
                "ORDER BY r.\"createdAt\" DESC",
                (rs, rn) -> mapReview(rs),
                eventId
        );
    }

    /**
     * Check whether the given user has participated in the given event.
     */
    public boolean isParticipant(String eventId, String userId) {
        Integer v = jdbcTemplate.query(
                "SELECT 1 FROM events.\"Participant\" WHERE \"eventId\" = ? AND \"userId\" = ? LIMIT 1",
                rs -> rs.next() ? 1 : 0,
                eventId, userId
        );
        return v != null && v == 1;
    }

    /**
     * Check whether the event has already ended.
     */
    public boolean isEventEnded(String eventId) {
        Integer v = jdbcTemplate.query(
                "SELECT 1 FROM events.\"Event\" WHERE id = ? " +
                "AND COALESCE(\"endDateTime\", \"dateTime\" + interval '3 hours') < NOW() LIMIT 1",
                rs -> rs.next() ? 1 : 0,
                eventId
        );
        return v != null && v == 1;
    }

    private EventDtos.RatingDto mapRating(ResultSet rs) throws SQLException {
        return new EventDtos.RatingDto(
                rs.getString("id"),
                rs.getString("userId"),
                rs.getString("eventId"),
                rs.getInt("rating"),
                rs.getString("comment"),
                toInstant(rs.getObject("createdAt"))
        );
    }

        private EventDtos.RatingReviewDto mapReview(ResultSet rs) throws SQLException {
        EventDtos.UserPreviewDto u = new EventDtos.UserPreviewDto(
            rs.getString("u_id"),
            rs.getString("u_displayName"),
            rs.getString("u_photoUrl"),
            rs.getString("u_email")
        );
        return new EventDtos.RatingReviewDto(
            rs.getString("id"),
            rs.getString("userId"),
            rs.getString("eventId"),
            rs.getInt("rating"),
            rs.getString("comment"),
            toInstant(rs.getObject("createdAt")),
            u
        );
        }

    private Instant toInstant(Object ts) {
        if (ts == null) return null;
        if (ts instanceof Timestamp t) return t.toInstant();
        if (ts instanceof java.time.OffsetDateTime odt) return odt.toInstant();
        if (ts instanceof java.time.LocalDateTime ldt) return ldt.atZone(java.time.ZoneOffset.UTC).toInstant();
        return null;
    }
}
