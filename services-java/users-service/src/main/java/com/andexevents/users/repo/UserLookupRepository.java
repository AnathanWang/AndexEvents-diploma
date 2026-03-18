package com.andexevents.users.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class UserLookupRepository {
    private final JdbcTemplate jdbcTemplate;

    public UserLookupRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<String> findUserIdByFirebaseUid(String firebaseUid) {
        return jdbcTemplate.query(
                "SELECT id FROM users.\"User\" WHERE \"firebaseUid\" = ? OR \"supabaseUid\" = ?",
                rs -> rs.next() ? Optional.ofNullable(rs.getString("id")) : Optional.empty(),
                firebaseUid,
                firebaseUid
        );
    }

    public Optional<String> findUserIdByEmail(String email) {
        return jdbcTemplate.query(
                "SELECT id FROM users.\"User\" WHERE lower(email) = lower(?)",
                rs -> rs.next() ? Optional.ofNullable(rs.getString("id")) : Optional.empty(),
                email
        );
    }
}
