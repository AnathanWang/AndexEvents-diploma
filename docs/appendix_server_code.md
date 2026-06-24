services-java/events-service/src/main/java/com/andexevents/events/repo/EventRepository.java — Репозиторий событий (PostGIS)

package com.andexevents.events.repo;

import com.andexevents.events.model.EventDtos;
import org.springframework.jdbc.core.JdbcTemplate;
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

        String imageUrl = p.imageUrl();
        if ((imageUrl == null || imageUrl.isBlank()) && p.imageUrls() != null && !p.imageUrls().isEmpty()) {
            imageUrl = p.imageUrls().get(0);
        }

        jdbcTemplate.update(
            "INSERT INTO events.\"Event\" (id, title, description, category, location, latitude, longitude, \"locationGeo\", \"dateTime\", \"endDateTime\", price, \"imageUrl\", \"imageUrls\", \"isOnline\", status, \"createdById\", \"createdAt\", \"updatedAt\") " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?, ?, ?, ?, ?::text[], ?, 'APPROVED'::events.\"EventStatus\", ?, NOW(), NOW())",
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
                imageUrl,
                toPgTextArrayLiteral(p.imageUrls()),
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

    public long countGoingParticipants(String eventId) {
        Long v = jdbcTemplate.queryForObject(
                "SELECT COUNT(1) FROM events.\"Participant\" WHERE \"eventId\" = ? AND status = 'GOING'::events.\"ParticipantStatus\"",
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
                "SELECT * FROM events.\"Event\" WHERE status = 'APPROVED'::events.\"EventStatus\" " +
                "AND NOT EXISTS (" +
                "  SELECT 1 FROM events.\"EventSanction\" s " +
                "  WHERE s.\"eventId\" = events.\"Event\".id " +
                "    AND s.\"type\" = 'HIDE_VISIBILITY'::events.\"EventSanctionType\" " +
                "    AND s.\"revokedAt\" IS NULL " +
                "    AND (s.\"expiresAt\" IS NULL OR s.\"expiresAt\" > NOW())" +
                ") " +
                "AND COALESCE(\"endDateTime\", \"dateTime\" + interval '3 hours') > NOW() " +
                "ORDER BY \"createdAt\" DESC",
                (rs, rn) -> mapEventRow(rs)
        );
    }

    /**
     * Same as {@link #listApprovedEvents()}, but does NOT hide events with HIDE_VISIBILITY sanctions.
     * Used for admin/moderation views where moderators must still see the event.
     */
    public List<EventRow> listApprovedEventsIncludingHidden() {
        return jdbcTemplate.query(
                "SELECT * FROM events.\"Event\" WHERE status = 'APPROVED'::events.\"EventStatus\" " +
                        "AND COALESCE(\"endDateTime\", \"dateTime\" + interval '3 hours') > NOW() " +
                        "ORDER BY \"createdAt\" DESC",
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

        String categoryClause = (category == null || category.isBlank()) ? "" : " AND e.category ILIKE ? ";

        String sql =
                "SELECT e.*, " +
                        "ST_Distance(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography) as distance, " +
                        "u.id as u_id, u.\"displayName\" as u_displayName, u.\"photoUrl\" as u_photoUrl, " +
                        "COUNT(p.id) as \"participantCount\" " +
                        "FROM events.\"Event\" e " +
                        "LEFT JOIN users.\"User\" u ON e.\"createdById\" = u.id " +
                        "LEFT JOIN events.\"Participant\" p ON e.id = p.\"eventId\" " +
                        "WHERE e.status = 'APPROVED'::events.\"EventStatus\" AND e.\"isOnline\" = false " +
                        "AND NOT EXISTS (" +
                        "  SELECT 1 FROM events.\"EventSanction\" s " +
                        "  WHERE s.\"eventId\" = e.id " +
                        "    AND s.\"type\" = 'HIDE_VISIBILITY'::events.\"EventSanctionType\" " +
                        "    AND s.\"revokedAt\" IS NULL " +
                        "    AND (s.\"expiresAt\" IS NULL OR s.\"expiresAt\" > NOW())" +
                        ") " +
                        "AND ST_DWithin(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?) " +
                        "AND COALESCE(e.\"endDateTime\", e.\"dateTime\" + interval '3 hours') > NOW() " +
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
            finalParams.add("%" + category + "%");
        }
        finalParams.add(limit);
        finalParams.add(offset);

        List<NearbyEventRow> events = jdbcTemplate.query(
                sql,
                (rs, rn) -> {
                    EventRow event = mapEventRow(rs);
                    double distance = rs.getDouble("distance");
                    long participantCount = rs.getLong("participantCount");
                    EventDtos.CreatorDto createdBy = null;
                    String creatorId = rs.getString("u_id");
                    if (creatorId != null) {
                        createdBy = new EventDtos.CreatorDto(creatorId, rs.getString("u_displayName"), rs.getString("u_photoUrl"));
                    }
                    return new NearbyEventRow(event, distance, createdBy, participantCount);
                },
                finalParams.toArray()
        );

        String countSql =
                "SELECT COUNT(DISTINCT e.id) " +
                        "FROM events.\"Event\" e " +
                        "WHERE e.status = 'APPROVED'::events.\"EventStatus\" AND e.\"isOnline\" = false " +
                        "AND NOT EXISTS (" +
                        "  SELECT 1 FROM events.\"EventSanction\" s " +
                        "  WHERE s.\"eventId\" = e.id " +
                        "    AND s.\"type\" = 'HIDE_VISIBILITY'::events.\"EventSanctionType\" " +
                        "    AND s.\"revokedAt\" IS NULL " +
                        "    AND (s.\"expiresAt\" IS NULL OR s.\"expiresAt\" > NOW())" +
                        ") " +
                        "AND ST_DWithin(e.\"locationGeo\", ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?) " +
                        "AND COALESCE(e.\"endDateTime\", e.\"dateTime\" + interval '3 hours') > NOW() " +
                        categoryClause;

        List<Object> countParams = new ArrayList<>();
        countParams.add(lon);
        countParams.add(lat);
        countParams.add(maxDistanceMeters);
        if (!categoryClause.isEmpty()) countParams.add("%" + category + "%");

        Integer total = jdbcTemplate.queryForObject(countSql, Integer.class, countParams.toArray());
        return new NearbyQueryResult(events, total == null ? 0 : total);
    }

    public Optional<EventRow> updateEvent(String eventId, EventUpdateParams p) {
        // For simplicity use update + re-read
        jdbcTemplate.update(
                "UPDATE events.\"Event\" SET title = COALESCE(?, title), description = COALESCE(?, description), category = COALESCE(?, category), " +
                        "location = COALESCE(?, location), latitude = COALESCE(?, latitude), longitude = COALESCE(?, longitude), " +
                        "\"locationGeo\" = CASE WHEN ? IS NOT NULL AND ? IS NOT NULL THEN ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography ELSE \"locationGeo\" END, " +
                    "\"dateTime\" = COALESCE(?, \"dateTime\"), \"endDateTime\" = COALESCE(?, \"endDateTime\"), price = COALESCE(?, price), \"imageUrl\" = COALESCE(?, \"imageUrl\"), \"imageUrls\" = COALESCE(?::text[], \"imageUrls\"), \"isOnline\" = COALESCE(?, \"isOnline\"), \"updatedAt\" = NOW() " +
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
                toPgTextArrayLiteral(p.imageUrls()),
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
            List<String> imageUrls,
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
            List<String> imageUrls,
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
            List<String> imageUrls,
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
                readTextArray(rs.getArray("imageUrls")),
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

    private List<String> readTextArray(java.sql.Array sqlArray) throws SQLException {
        if (sqlArray == null) return List.of();
        Object value = sqlArray.getArray();
        if (value instanceof String[] arr) return Arrays.asList(arr);
        if (value instanceof Object[] arr) {
            List<String> out = new ArrayList<>();
            for (Object item : arr) {
                if (item != null) out.add(item.toString());
            }
            return out;
        }
        return List.of();
    }

    private String toPgTextArrayLiteral(List<String> values) {
        if (values == null) return null;
        if (values.isEmpty()) return "{}";

        StringJoiner joiner = new StringJoiner(",", "{", "}");
        for (String value : values) {
            String escaped = value == null ? "" : value
                    .replace("\\", "\\\\")
                    .replace("\"", "\\\"");
            joiner.add("\"" + escaped + "\"");
        }
        return joiner.toString();
    }
}

services-java/users-service/src/main/java/com/andexevents/users/util/MatchRecommendationScorer.java — Скорер ленты знакомств

package com.andexevents.users.util;

import com.andexevents.users.model.UserDto;

import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Rule-based match feed ranking (no ML):
 * incoming like → shared GOING events → common interests → distance → profile completeness.
 */
public final class MatchRecommendationScorer {

    static final int INCOMING_LIKE_BOOST = 1_000;
    static final int SHARED_GOING_EVENT_WEIGHT = 80;
    static final int COMMON_INTEREST_WEIGHT = 120;
    static final double DISTANCE_PENALTY_PER_KM = 3.0;
    static final int PROFILE_PHOTO_BOOST = 15;
    static final int PROFILE_BIO_BOOST = 5;
    static final int MISSING_PHOTO_PENALTY = 25;
    static final int MISSING_INTERESTS_PENALTY = 20;
    static final int MISSING_BIO_PENALTY = 10;
    static final int EMPTY_PROFILE_PENALTY = 60;

    private MatchRecommendationScorer() {
    }

    public static int score(
            UserDto candidate,
            UserDto currentUser,
            Set<String> incomingLikeUserIds,
            Map<String, Integer> sharedGoingEventCounts,
            double originLat,
            double originLon
    ) {
        int score = 0;

        if (incomingLikeUserIds != null && incomingLikeUserIds.contains(candidate.id())) {
            score += INCOMING_LIKE_BOOST;
        }

        if (sharedGoingEventCounts != null) {
            int sharedEvents = sharedGoingEventCounts.getOrDefault(candidate.id(), 0);
            score += Math.max(sharedEvents, 0) * SHARED_GOING_EVENT_WEIGHT;
        }

        score += countCommonInterests(currentUser.interests(), candidate.interests()) * COMMON_INTEREST_WEIGHT;

        Double candidateLat = candidate.lastLatitude();
        Double candidateLon = candidate.lastLongitude();
        if (candidateLat != null && candidateLon != null) {
            double distanceKm = haversineKm(originLat, originLon, candidateLat, candidateLon);
            score -= (int) Math.round(distanceKm * DISTANCE_PENALTY_PER_KM);
        }

        if (candidate.photoUrl() != null && !candidate.photoUrl().isBlank()) {
            score += PROFILE_PHOTO_BOOST;
        }
        if (candidate.bio() != null && !candidate.bio().isBlank()) {
            score += PROFILE_BIO_BOOST;
        }

        score -= profileCompletenessPenalty(candidate);

        return score;
    }

    static int profileCompletenessPenalty(UserDto candidate) {
        boolean hasPhoto = candidate.photoUrl() != null && !candidate.photoUrl().isBlank();
        boolean hasGallery = candidate.photos() != null && !candidate.photos().isEmpty();
        boolean hasBio = candidate.bio() != null && !candidate.bio().isBlank();
        boolean hasInterests = candidate.interests() != null && !candidate.interests().isEmpty();

        if (!hasPhoto && !hasGallery && !hasBio && !hasInterests) {
            return EMPTY_PROFILE_PENALTY;
        }

        int penalty = 0;
        if (!hasPhoto && !hasGallery) {
            penalty += MISSING_PHOTO_PENALTY;
        }
        if (!hasInterests) {
            penalty += MISSING_INTERESTS_PENALTY;
        }
        if (!hasBio) {
            penalty += MISSING_BIO_PENALTY;
        }
        return penalty;
    }

    public static List<UserDto> rank(
            List<UserDto> candidates,
            UserDto currentUser,
            Set<String> incomingLikeUserIds,
            Map<String, Integer> sharedGoingEventCounts,
            double originLat,
            double originLon,
            int limit
    ) {
        if (candidates == null || candidates.isEmpty()) {
            return List.of();
        }

        int safeLimit = Math.max(limit, 1);
        return candidates.stream()
                .sorted(Comparator
                        .comparingInt((UserDto c) -> score(
                                c,
                                currentUser,
                                incomingLikeUserIds,
                                sharedGoingEventCounts,
                                originLat,
                                originLon
                        ))
                        .reversed()
                        .thenComparing(UserDto::id))
                .limit(safeLimit)
                .collect(Collectors.toList());
    }

    static Set<String> normalizeInterests(List<String> interests) {
        if (interests == null || interests.isEmpty()) {
            return Set.of();
        }
        Set<String> normalized = new HashSet<>();
        for (String interest : interests) {
            if (interest == null) {
                continue;
            }
            String value = interest.trim().toLowerCase(Locale.ROOT);
            if (!value.isEmpty()) {
                normalized.add(value);
            }
        }
        return normalized;
    }

    static int countCommonInterests(List<String> left, List<String> right) {
        Set<String> a = normalizeInterests(left);
        Set<String> b = normalizeInterests(right);
        if (a.isEmpty() || b.isEmpty()) {
            return 0;
        }
        int count = 0;
        for (String item : a) {
            if (b.contains(item)) {
                count++;
            }
        }
        return count;
    }

    static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }
}

services/match-service/internal/repository/match_repository.go — Репозиторий свайпов и взаимных матчей

package repository

import (
	"context"
	"encoding/json"
	"time"

	"database/sql"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type MatchRepository interface {
	CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error)
	GetMutualMatchUsers(ctx context.Context, userID, eventID string) ([]model.User, error)
	GetActionUsers(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error)
	GetIncomingLikeUsers(ctx context.Context, userID, eventID string, limit int) ([]model.User, error)
	GetUserByID(ctx context.Context, userID string) (model.User, error)
}

type PgxPoolIface interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type matchRepository struct {
	pool PgxPoolIface
}

func NewMatchRepository(pool PgxPoolIface) MatchRepository {
	return &matchRepository{pool: pool}
}

func (r *matchRepository) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error) {
	now := time.Now()

	// Пытаемся найти существующую запись в любом порядке
	selectQuery := `
		SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		FROM "Match"
		WHERE (("userAId" = $1 AND "userBId" = $2) OR ("userAId" = $2 AND "userBId" = $1)) 
		  AND COALESCE("eventId", '') = COALESCE($3, '')
		LIMIT 1
	`

	var existing model.Match
	var existingEventID sql.NullString
	var aAction, bAction *string
	err := r.pool.QueryRow(ctx, selectQuery, userID, targetUserID, eventID).Scan(
		&existing.ID,
		&existing.UserAID,
		&existing.UserBID,
		&existingEventID,
		&aAction,
		&bAction,
		&existing.IsMutual,
		&existing.MatchedAt,
		&existing.CreatedAt,
		&existing.UpdatedAt,
	)

	if err != nil && err != pgx.ErrNoRows {
		return nil, err
	}

	// Нет записи -> создаём
	if err == pgx.ErrNoRows {
		insertQuery := `
			INSERT INTO "Match" (
				id, "userAId", "userBId", "eventId", "userAAction", "isMutual", "createdAt", "updatedAt"
			) VALUES (
				$1, $2, $3, NULLIF($4, ''), $5, false, $6, $6
			)
			RETURNING id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		`
		id := uuid.New().String()
		actionStr := string(action)

		var created model.Match
		var createdEventID sql.NullString
		var ca, cb *string
		err := r.pool.QueryRow(ctx, insertQuery, id, userID, targetUserID, eventID, actionStr, now).Scan(
			&created.ID,
			&created.UserAID,
			&created.UserBID,
			&createdEventID,
			&ca,
			&cb,
			&created.IsMutual,
			&created.MatchedAt,
			&created.CreatedAt,
			&created.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		if ca != nil {
			a := model.MatchAction(*ca)
			created.UserAAction = &a
		}
		if cb != nil {
			b := model.MatchAction(*cb)
			created.UserBAction = &b
		}
		if createdEventID.Valid {
			created.EventID = createdEventID.String
		}
		return &created, nil
	}

	if aAction != nil {
		a := model.MatchAction(*aAction)
		existing.UserAAction = &a
	}
	if bAction != nil {
		b := model.MatchAction(*bAction)
		existing.UserBAction = &b
	}
	if existingEventID.Valid {
		existing.EventID = existingEventID.String
	}

	// Обновляем действие для текущего пользователя
	var otherAction *model.MatchAction
	setColumn := `"userAAction"`
	if existing.UserAID == userID {
		otherAction = existing.UserBAction
		setColumn = `"userAAction"`
	} else {
		otherAction = existing.UserAAction
		setColumn = `"userBAction"`
	}

	isMutual := false
	if otherAction != nil {
		isMutual = otherAction.IsLikeType() && action.IsLikeType()
	}

	var matchedAt interface{} = nil
	if isMutual {
		matchedAt = now
	}

	updateQuery := `
		UPDATE "Match"
		SET ` + setColumn + ` = $1, "isMutual" = $2, "matchedAt" = $3, "updatedAt" = $4
		WHERE id = $5
		RETURNING id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
	`

	actionStr := string(action)
	var updated model.Match
	var updatedEventID sql.NullString
	var ua, ub *string
	err = r.pool.QueryRow(ctx, updateQuery, actionStr, isMutual, matchedAt, now, existing.ID).Scan(
		&updated.ID,
		&updated.UserAID,
		&updated.UserBID,
		&updatedEventID,
		&ua,
		&ub,
		&updated.IsMutual,
		&updated.MatchedAt,
		&updated.CreatedAt,
		&updated.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if ua != nil {
		a := model.MatchAction(*ua)
		updated.UserAAction = &a
	}
	if ub != nil {
		b := model.MatchAction(*ub)
		updated.UserBAction = &b
	}
	if updatedEventID.Valid {
		updated.EventID = updatedEventID.String
	}

	return &updated, nil
}

func scanUser(row pgx.Row, dest *model.User) error {
	var interests []string
	var photos []string
	var socialLinks []byte

	err := row.Scan(
		&dest.ID,
		&dest.SupabaseUID,
		&dest.Email,
		&dest.DisplayName,
		&dest.PhotoURL,
		&photos,
		&dest.Bio,
		&interests,
		&socialLinks,
		&dest.Age,
		&dest.Gender,
		&dest.Role,
		&dest.LastLatitude,
		&dest.LastLongitude,
		&dest.LastLocationUpdate,
		&dest.IsProfileVisible,
		&dest.IsLocationVisible,
		&dest.ShowVisitedEvents,
		&dest.ShowInMatches,
		&dest.IncognitoMode,
		&dest.HideOnlineStatus,

		&dest.MinAge,
		&dest.MaxAge,
		&dest.MaxDistance,
		&dest.FCMToken,
		&dest.IsOnboardingCompleted,
		&dest.CreatedAt,
		&dest.UpdatedAt,
	)
	if err != nil {
		return err
	}

	dest.Interests = interests
	dest.Photos = photos
	if socialLinks != nil {
		dest.SocialLinks = json.RawMessage(socialLinks)
	}

	return nil
}

func (r *matchRepository) GetMutualMatchUsers(ctx context.Context, userID, eventID string) ([]model.User, error) {
	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE m."isMutual" = true
		  AND (m."userAId" = $1 OR m."userBId" = $1)
		  AND ($2 = '' OR COALESCE(m."eventId", '') = COALESCE($2, ''))
		ORDER BY m."matchedAt" DESC NULLS LAST, m."updatedAt" DESC
	`

	rows, err := r.pool.Query(ctx, query, userID, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]model.User, 0)
	for rows.Next() {
		var u model.User
		if err := scanUser(rows, &u); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

func (r *matchRepository) GetActionUsers(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE (CASE WHEN m."userAId" = $1 THEN m."userAAction" ELSE m."userBAction" END) = $3
		  AND (m."userAId" = $1 OR m."userBId" = $1)
		  AND ($4 = '' OR COALESCE(m."eventId", '') = COALESCE($4, ''))
		ORDER BY m."updatedAt" DESC
		LIMIT $2
	`

	rows, err := r.pool.Query(ctx, query, userID, limit, string(action), eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]model.User, 0)
	for rows.Next() {
		var u model.User
		if err := scanUser(rows, &u); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

func (r *matchRepository) GetIncomingLikeUsers(ctx context.Context, userID, eventID string, limit int) ([]model.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE
			(m."userAId" = $1 OR m."userBId" = $1)
			AND (CASE WHEN m."userAId" = $1 THEN m."userBAction" ELSE m."userAAction" END) IN ($3, $4)
			AND (CASE WHEN m."userAId" = $1 THEN m."userAAction" ELSE m."userBAction" END) IS NULL
			AND m."isMutual" = false
			AND ($5 = '' OR COALESCE(m."eventId", '') = COALESCE($5, ''))
		ORDER BY m."updatedAt" DESC
		LIMIT $2
	`

	rows, err := r.pool.Query(
		ctx,
		query,
		userID,
		limit,
		string(model.MatchActionLike),
		string(model.MatchActionSuperLike),
		eventID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]model.User, 0)
	for rows.Next() {
		var u model.User
		if err := scanUser(rows, &u); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

func (r *matchRepository) GetUserByID(ctx context.Context, userID string) (model.User, error) {
	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM users."User" u
		WHERE u.id = $1
		LIMIT 1
	`

	var user model.User
	if err := scanUser(r.pool.QueryRow(ctx, query, userID), &user); err != nil {
		return model.User{}, err
	}

	return user, nil
}

services-java/events-service/src/main/java/com/andexevents/events/auth/AuthFilter.java — Фильтр JWT-авторизации

package com.andexevents.events.auth;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.repo.UserLookupRepository;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Component
public class AuthFilter extends OncePerRequestFilter {
    public static final String ATTR = "andex.auth";

    private final FirebaseJwtVerifier jwtVerifier;
    private final UserLookupRepository userLookupRepository;
    private final ObjectMapper objectMapper;

    private final RequestMatcher required;
    private final RequestMatcher optional;
    private final RequestMatcher publicMatcher;
    private final boolean defaultRequireAuth;

    public AuthFilter(
            AuthConfigProperties props,
            FirebaseJwtVerifier jwtVerifier,
            UserLookupRepository userLookupRepository,
            ObjectMapper objectMapper
    ) {
        this.jwtVerifier = jwtVerifier;
        this.userLookupRepository = userLookupRepository;
        this.objectMapper = objectMapper;
        this.defaultRequireAuth = props.isDefaultRequireAuth();

        this.required = toMatcher(props.getRequiredPaths());
        this.optional = toMatcher(props.getOptionalPaths());
        this.publicMatcher = toPublicMatcher(props);
    }

    private RequestMatcher toMatcher(List<AuthConfigProperties.PathRule> rules) {
        List<RequestMatcher> matchers = rules.stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList();
        return matchers.isEmpty() ? request -> false : new OrRequestMatcher(matchers);
    }

    private RequestMatcher toPublicMatcher(AuthConfigProperties props) {
        List<RequestMatcher> matchers = new ArrayList<>();

        // Explicit public paths (new, prod-safe configuration)
        matchers.addAll(props.getPublicPaths().stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList());

        // Backward compatible behavior: "optionalPaths" are considered public (auth is optional).
        matchers.addAll(props.getOptionalPaths().stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList());

        // Always-public introspection endpoints
        matchers.add(new AntPathRequestMatcher("/health", null));
        matchers.add(new AntPathRequestMatcher("/actuator/**", null));
        matchers.add(new AntPathRequestMatcher("/swagger-ui/**", null));
        matchers.add(new AntPathRequestMatcher("/v3/api-docs/**", null));

        return matchers.isEmpty() ? request -> false : new OrRequestMatcher(matchers);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!defaultRequireAuth) {
            return !(required.matches(request) || optional.matches(request));
        }
        return publicMatcher.matches(request);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        boolean isPublic = publicMatcher.matches(request);
        boolean requireAuth = defaultRequireAuth ? !isPublic : required.matches(request);

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: No token provided");
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring("Bearer ".length()).trim();
        if (token.isBlank()) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: Invalid token format");
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        try {
            DecodedJWT decoded = jwtVerifier.verify(token);
            String uid = decoded.getSubject();
            String email = decoded.getClaim("email").asString();

            if (uid != null && !uid.isBlank()) {
                String userId = userLookupRepository.findUserIdByFirebaseUid(uid).orElse(null);
                if (userId == null && email != null && !email.isBlank()) {
                    userId = userLookupRepository.findUserIdByEmail(email).orElse(null);
                }
                request.setAttribute(ATTR, new AuthContext(uid, email, userId));
            }

            filterChain.doFilter(request, response);
        } catch (JWTVerificationException ex) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: Invalid token");
                return;
            }
            // Public endpoints: ignore invalid token.
            filterChain.doFilter(request, response);
        }
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(message));
    }
}

services-java/events-service/src/main/java/com/andexevents/events/auth/FirebaseJwtVerifier.java — Верификация Firebase JWT (JWKS)

package com.andexevents.events.auth;

import com.auth0.jwk.Jwk;
import com.auth0.jwk.JwkProvider;
import com.auth0.jwk.JwkProviderBuilder;
import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.springframework.stereotype.Component;

import java.net.URL;
import java.security.interfaces.RSAPublicKey;
import java.util.concurrent.TimeUnit;

@Component
public class FirebaseJwtVerifier {
    private static final String DEFAULT_JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    private final String projectId;
    private final JwkProvider jwkProvider;

    public FirebaseJwtVerifier(AuthConfigProperties props) {
        this.projectId = props.getFirebaseProjectId();
        if (this.projectId == null || this.projectId.isBlank()) {
            throw new JWTVerificationException("FIREBASE_PROJECT_ID is not configured");
        }

        String jwksUrl = props.getFirebaseJwksUrl();
        if (jwksUrl == null || jwksUrl.isBlank()) {
            jwksUrl = DEFAULT_JWKS_URL;
        }

        try {
            this.jwkProvider = new JwkProviderBuilder(new URL(jwksUrl))
                    .cached(10, 24, TimeUnit.HOURS)
                    .rateLimited(10, 1, TimeUnit.MINUTES)
                    .build();
        } catch (Exception ex) {
            throw new JWTVerificationException("Failed to initialize JWKS provider", ex);
        }
    }

    public DecodedJWT verify(String token) {
        try {
            DecodedJWT decoded = JWT.decode(token);
            String kid = decoded.getKeyId();
            if (kid == null || kid.isBlank()) {
                throw new JWTVerificationException("Missing kid header");
            }

            Jwk jwk = jwkProvider.get(kid);
            Algorithm algorithm = Algorithm.RSA256((RSAPublicKey) jwk.getPublicKey(), null);

            String issuer = "https://securetoken.google.com/" + projectId;
            JWTVerifier verifier = JWT.require(algorithm)
                    .withIssuer(issuer)
                    .withAudience(projectId)
                    .build();

            return verifier.verify(token);
        } catch (JWTVerificationException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new JWTVerificationException("Invalid token", ex);
        }
    }
}
