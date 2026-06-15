package com.andexevents.users.repo;

import com.andexevents.users.model.GlobalMatchContext;
import com.andexevents.users.model.UserDto;
import com.andexevents.users.service.UserService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.*;
import java.util.UUID;

@Repository
public class UserRepository {
    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public UserRepository(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public Optional<UserDto> findByEmail(String email) {
        List<UserDto> rows = jdbcTemplate.query(
                "SELECT * FROM users.\"User\" WHERE email = ?",
                mapper(),
                email
        );
        return rows.stream().findFirst();
    }

    public Optional<UserDto> findById(String id) {
        List<UserDto> rows = jdbcTemplate.query(
                "SELECT * FROM users.\"User\" WHERE id = ?",
                mapper(),
                id
        );
        return rows.stream().findFirst();
    }

    public List<UserDto> findAllForModeration() {
        return jdbcTemplate.query(
                "SELECT * FROM users.\"User\" ORDER BY \"createdAt\" DESC",
                mapper()
        );
    }

    public Optional<UserDto> findByFirebaseUid(String firebaseUid) {
        List<UserDto> rows = jdbcTemplate.query(
                "SELECT * FROM users.\"User\" WHERE \"firebaseUid\" = ? OR \"supabaseUid\" = ?",
                mapper(),
                firebaseUid,
                firebaseUid
        );
        return rows.stream().findFirst();
    }

    public UserDto insertUser(String id, String firebaseUid, String email, String displayName, String photoUrl) {
        jdbcTemplate.update(
                "INSERT INTO users.\"User\" (id, \"firebaseUid\", \"supabaseUid\", email, \"displayName\", \"photoUrl\", \"createdAt\", \"updatedAt\") VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())",
                id,
                firebaseUid,
                firebaseUid,
                email,
                displayName,
                photoUrl
        );
        return findById(id).orElseThrow();
    }

    public UserDto updateFirebaseUid(String userId, String firebaseUid) {
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"firebaseUid\" = ?, \"supabaseUid\" = COALESCE(\"supabaseUid\", ?), \"updatedAt\" = NOW() WHERE id = ?",
                firebaseUid,
                firebaseUid,
                userId
        );
        return findById(userId).orElseThrow();
    }

    public UserDto updateProfile(String userId, Map<String, Object> updates) {
        if (updates.isEmpty()) {
            return findById(userId).orElseThrow();
        }

        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("UPDATE users.\"User\" SET ");

        int i = 0;
        for (Map.Entry<String, Object> e : updates.entrySet()) {
            if (i++ > 0) sql.append(", ");
            sql.append('"').append(e.getKey()).append('"').append(" = ");

            if ("socialLinks".equals(e.getKey())) {
                sql.append("CAST(? AS jsonb)");
                try {
                    params.add(objectMapper.writeValueAsString(e.getValue()));
                } catch (Exception ex) {
                    throw new IllegalArgumentException("Failed to serialize socialLinks", ex);
                }
            } else {
                sql.append("?");
                params.add(e.getValue());
            }
        }
        sql.append(", \"updatedAt\" = NOW() WHERE id = ?");
        params.add(userId);

        jdbcTemplate.update(sql.toString(), params.toArray());
        return findById(userId).orElseThrow();
    }

    public Map<String, Integer> findSharedGoingEventCounts(String userId, List<String> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            return Map.of();
        }

        String placeholders = String.join(", ", Collections.nCopies(candidateIds.size(), "?"));
        String sql = """
                SELECT p2."userId" AS candidate_id, COUNT(DISTINCT p2."eventId") AS shared_count
                FROM events."Participant" p1
                JOIN events."Participant" p2 ON p1."eventId" = p2."eventId"
                WHERE p1."userId" = ?
                  AND p2."userId" <> p1."userId"
                  AND p1.status = 'GOING'::events."ParticipantStatus"
                  AND p2.status = 'GOING'::events."ParticipantStatus"
                  AND p2."userId" IN (%s)
                GROUP BY p2."userId"
                """.formatted(placeholders);

        List<Object> params = new ArrayList<>();
        params.add(userId);
        params.addAll(candidateIds);

        Map<String, Integer> counts = new HashMap<>();
        try {
            jdbcTemplate.query(
                    sql,
                    rs -> {
                        counts.put(rs.getString("candidate_id"), rs.getInt("shared_count"));
                    },
                    params.toArray()
            );
        } catch (Exception ignored) {
            // events schema may be unavailable in isolated test DB
            return Map.of();
        }
        return counts;
    }

    public void updateLocation(String userId, double latitude, double longitude) {
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"lastLatitude\" = ?, \"lastLongitude\" = ?, \"lastLocationUpdate\" = NOW(), \"updatedAt\" = NOW() WHERE id = ?",
                latitude,
                longitude,
                userId
        );
    }

    public GlobalMatchContext findGlobalMatchContext(String userId) {
        String sql = """
                SELECT
                  CASE WHEN "userAId" = ? THEN "userBId" ELSE "userAId" END AS other_id,
                  CASE WHEN "userAId" = ? THEN "userAAction" ELSE "userBAction" END AS my_action,
                  CASE WHEN "userAId" = ? THEN "userBAction" ELSE "userAAction" END AS their_action,
                  COALESCE("isMutual", false) AS is_mutual
                FROM "Match"
                WHERE COALESCE("eventId", '') = ''
                  AND (? = "userAId" OR ? = "userBId")
                """;

        Set<String> actioned = new HashSet<>();
        Set<String> incomingLikes = new HashSet<>();
        Set<String> mutual = new HashSet<>();

        jdbcTemplate.query(
                sql,
                rs -> {
                    String otherId = rs.getString("other_id");
                    String myAction = rs.getString("my_action");
                    String theirAction = rs.getString("their_action");
                    boolean isMutual = rs.getBoolean("is_mutual");

                    if (otherId == null || otherId.isBlank()) {
                        return;
                    }

                    if (isMutual) {
                        mutual.add(otherId);
                    }
                    if (myAction != null && !myAction.isBlank()) {
                        actioned.add(otherId);
                    }
                    if (!isMutual
                            && (myAction == null || myAction.isBlank())
                            && isLikeAction(theirAction)) {
                        incomingLikes.add(otherId);
                    }
                },
                userId,
                userId,
                userId,
                userId,
                userId
        );

        return new GlobalMatchContext(actioned, incomingLikes, mutual);
    }

    private static boolean isLikeAction(String action) {
        if (action == null) {
            return false;
        }
        String normalized = action.trim().toUpperCase(Locale.ROOT);
        return "LIKE".equals(normalized) || "SUPER_LIKE".equals(normalized);
    }

    public List<UserDto> findMatches(
            String userId,
            double userLat,
            double userLon,
            double radiusKm,
            int limit,
            Integer minAge,
            Integer maxAge
    ) {
        double earthRadiusKm = 6371.0;
        double latChange = (radiusKm / earthRadiusKm) * (180.0 / Math.PI);
        double lonChange = (radiusKm / (earthRadiusKm * Math.cos((userLat * Math.PI) / 180.0))) * (180.0 / Math.PI);

        double minLat = userLat - latChange;
        double maxLat = userLat + latChange;
        double minLon = userLon - lonChange;
        double maxLon = userLon + lonChange;

        StringBuilder sql = new StringBuilder(
            "SELECT u.* FROM users.\"User\" u WHERE u.id <> ? " +
                "AND u.\"isOnboardingCompleted\" = true " +
                "AND u.\"isProfileVisible\" = true " +
                "AND u.\"showInMatches\" = true " +
                "AND (" +
                "    u.\"incognitoMode\" = false " +
                "    OR EXISTS (" +
                "        SELECT 1 FROM \"Match\" m " +
                "        WHERE (m.\"userAId\" = u.id AND m.\"userBId\" = ? AND m.\"userAAction\" = 'LIKE') " +
                "           OR (m.\"userBId\" = u.id AND m.\"userAId\" = ? AND m.\"userBAction\" = 'LIKE')" +
                "    )" +
                ") " +
                "AND u.\"lastLatitude\" BETWEEN ? AND ? " +
                "AND u.\"lastLongitude\" BETWEEN ? AND ? " +
                "AND NOT EXISTS (" +
                "SELECT 1 FROM users.\"UserBlock\" b WHERE (b.\"blockerId\" = ? AND b.\"targetUserId\" = u.id) OR (b.\"blockerId\" = u.id AND b.\"targetUserId\" = ?)) " +
                "AND NOT EXISTS (" +
                "SELECT 1 FROM \"Match\" m " +
                "WHERE COALESCE(m.\"eventId\", '') = '' " +
                "AND (" +
                "  (m.\"userAId\" = ? AND m.\"userBId\" = u.id AND m.\"userAAction\" IS NOT NULL) " +
                "  OR (m.\"userBId\" = ? AND m.\"userAId\" = u.id AND m.\"userBAction\" IS NOT NULL) " +
                "  OR (COALESCE(m.\"isMutual\", false) = true AND ((m.\"userAId\" = ? AND m.\"userBId\" = u.id) OR (m.\"userBId\" = ? AND m.\"userAId\" = u.id)))" +
                ")) "
        );

        List<Object> params = new ArrayList<>();
        params.add(userId);
        params.add(userId);
        params.add(userId);
        params.add(minLat);
        params.add(maxLat);
        params.add(minLon);
        params.add(maxLon);
        params.add(userId);
        params.add(userId);
        params.add(userId);
        params.add(userId);
        params.add(userId);
        params.add(userId);

        if (minAge != null) {
            sql.append("AND age >= ? ");
            params.add(minAge);
        }
        if (maxAge != null) {
            sql.append("AND age <= ? ");
            params.add(maxAge);
        }

        sql.append("LIMIT ?");
        params.add(limit);

        return jdbcTemplate.query(sql.toString(), mapper(), params.toArray());
    }

    private RowMapper<UserDto> mapper() {
        return (rs, rowNum) -> mapUser(rs);
    }

    private UserDto mapUser(ResultSet rs) throws SQLException {
        return mapUser(rs, null, null);
    }

    private UserDto mapUser(ResultSet rs, Double averageRating, Long eventsCreatedCount) throws SQLException {
        Array interestsArr = rs.getArray("interests");
        List<String> interests = interestsArr == null ? List.of() : Arrays.asList((String[]) interestsArr.getArray());

        Array photosArr = rs.getArray("photos");
        List<String> photos = photosArr == null ? List.of() : Arrays.asList((String[]) photosArr.getArray());

        Map<String, Object> socialLinks = null;
        String socialLinksJson = rs.getString("socialLinks");
        if (socialLinksJson != null) {
            try {
                socialLinks = objectMapper.readValue(socialLinksJson, new TypeReference<>() {});
            } catch (Exception ignored) {
                socialLinks = null;
            }
        }

        return new UserDto(
                rs.getString("id"),
                rs.getString("firebaseUid"),
                rs.getString("email"),
                rs.getString("displayName"),
                rs.getString("photoUrl"),
                rs.getString("coverImageUrl"),
                photos,
                rs.getString("bio"),
                interests,
                socialLinks,
                (Integer) rs.getObject("age"),
                rs.getString("gender"),
                rs.getString("role"),
                (Double) rs.getObject("lastLatitude"),
                (Double) rs.getObject("lastLongitude"),
                toInstant(rs.getObject("lastLocationUpdate")),
                (Boolean) rs.getObject("isProfileVisible"),
                (Boolean) rs.getObject("isLocationVisible"),
                (Integer) rs.getObject("minAge"),
                (Integer) rs.getObject("maxAge"),
                (Integer) rs.getObject("maxDistance"),
                (Boolean) rs.getObject("showVisitedEvents"),
                (Boolean) rs.getObject("showInMatches"),
                (Boolean) rs.getObject("incognitoMode"),
                (Boolean) rs.getObject("hideOnlineStatus"),
                rs.getString("fcmToken"),
                (Boolean) rs.getObject("isOnboardingCompleted"),
                toInstant(rs.getObject("createdAt")),
                toInstant(rs.getObject("updatedAt")),
                averageRating,
                eventsCreatedCount
        );
    }

    /**
     * Find a user by ID and enrich with organizer rating from events schema.
     * averageRating/eventsCreatedCount are null if user has fewer than 3 approved events.
     */
    public Optional<UserDto> findByIdWithRating(String id) {
        List<UserDto> rows = jdbcTemplate.query(
                "SELECT u.*, " +
                "  COUNT(DISTINCT e.id) AS events_count, " +
                "  CASE WHEN COUNT(DISTINCT e.id) >= 3 THEN AVG(r.rating) ELSE NULL END AS avg_rating " +
                "FROM users.\"User\" u " +
                "LEFT JOIN events.\"Event\" e ON e.\"createdById\" = u.id AND e.status = 'APPROVED' " +
                "LEFT JOIN events.\"EventRating\" r ON r.\"eventId\" = e.id " +
                "WHERE u.id = ? " +
                "GROUP BY u.id",
                (rs, rn) -> {
                    long eventsCount = rs.getLong("events_count");
                    Object val = rs.getObject("avg_rating");
                    Double avgRating = null;
                    if (eventsCount >= 3 && val != null) {
                        if (val instanceof java.math.BigDecimal bd) {
                            avgRating = bd.doubleValue();
                        } else if (val instanceof Double d) {
                            avgRating = d;
                        } else {
                            avgRating = rs.getDouble("avg_rating");
                        }
                    }
                    Long eventsCreatedCount = eventsCount > 0 ? eventsCount : null;
                    try {
                        return mapUser(rs, avgRating, eventsCreatedCount);
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                },
                id
        );
        return rows.stream().findFirst();
    }

    public void addPhoto(String userId, String photoUrl) {
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"photos\" = array_append(COALESCE(\"photos\", ARRAY[]::text[]), ?), \"updatedAt\" = NOW() WHERE id = ?",
                photoUrl,
                userId
        );
    }

    public void removePhoto(String userId, String photoUrl) {
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"photos\" = array_remove(\"photos\", ?), \"updatedAt\" = NOW() WHERE id = ?",
                photoUrl,
                userId
        );
    }

    public void blockUser(String blockerId, String targetUserId) {
        jdbcTemplate.update(
                "INSERT INTO users.\"UserBlock\" (id, \"blockerId\", \"targetUserId\", \"createdAt\") VALUES (?, ?, ?, NOW()) ON CONFLICT (\"blockerId\", \"targetUserId\") DO NOTHING",
                UUID.randomUUID().toString(),
                blockerId,
                targetUserId
        );
    }

    public void unblockUser(String blockerId, String targetUserId) {
        jdbcTemplate.update(
                "DELETE FROM users.\"UserBlock\" WHERE \"blockerId\" = ? AND \"targetUserId\" = ?",
                blockerId,
                targetUserId
        );
    }

    public UserDto updateRole(String userId, String role) {
        int rowsUpdated = jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"role\" = CAST(? AS users.\"UserRole\"), \"updatedAt\" = NOW() WHERE id = ?",
                role,
                userId
        );

        if (rowsUpdated == 0) {
            throw new UserService.NotFoundException("User not found");
        }

        return findById(userId).orElseThrow();
    }

    private Instant toInstant(Object ts) {
        if (ts == null) return null;
        if (ts instanceof java.sql.Timestamp t) return t.toInstant();
        if (ts instanceof java.time.OffsetDateTime odt) return odt.toInstant();
        if (ts instanceof java.time.LocalDateTime ldt) return ldt.atZone(java.time.ZoneOffset.UTC).toInstant();
        return null;
    }
}
