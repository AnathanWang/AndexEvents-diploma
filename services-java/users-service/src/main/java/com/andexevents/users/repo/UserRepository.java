package com.andexevents.users.repo;

import com.andexevents.users.model.UserDto;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.*;

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
            sql.append('"').append(e.getKey()).append('"').append(" = ?");
            params.add(e.getValue());
        }
        sql.append(", \"updatedAt\" = NOW() WHERE id = ?");
        params.add(userId);

        jdbcTemplate.update(sql.toString(), params.toArray());
        return findById(userId).orElseThrow();
    }

    public void updateLocation(String userId, double latitude, double longitude) {
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"lastLatitude\" = ?, \"lastLongitude\" = ?, \"lastLocationUpdate\" = NOW(), \"updatedAt\" = NOW() WHERE id = ?",
                latitude,
                longitude,
                userId
        );
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
                "SELECT * FROM users.\"User\" WHERE id <> ? " +
                        "AND \"isOnboardingCompleted\" = true " +
                        "AND \"isProfileVisible\" = true " +
                        "AND \"lastLatitude\" BETWEEN ? AND ? " +
                        "AND \"lastLongitude\" BETWEEN ? AND ? "
        );

        List<Object> params = new ArrayList<>();
        params.add(userId);
        params.add(minLat);
        params.add(maxLat);
        params.add(minLon);
        params.add(maxLon);

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
        Array interestsArr = rs.getArray("interests");
        List<String> interests = interestsArr == null ? List.of() : Arrays.asList((String[]) interestsArr.getArray());

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
                rs.getString("fcmToken"),
                (Boolean) rs.getObject("isOnboardingCompleted"),
                toInstant(rs.getObject("createdAt")),
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
