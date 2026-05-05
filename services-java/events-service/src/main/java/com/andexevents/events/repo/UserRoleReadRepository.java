package com.andexevents.events.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UserRoleReadRepository {
    private final JdbcTemplate jdbcTemplate;

    public UserRoleReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String findRoleByUserId(String userId) {
        return jdbcTemplate.query(
                "SELECT role FROM users.\"User\" WHERE id = ?",
                rs -> rs.next() ? rs.getString("role") : null,
                userId
        );
    }
}

