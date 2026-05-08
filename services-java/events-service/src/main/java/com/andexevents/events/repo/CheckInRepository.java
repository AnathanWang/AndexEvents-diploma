package com.andexevents.events.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.HashSet;
import java.util.Set;

@Repository
public class CheckInRepository {
    private final JdbcTemplate jdbcTemplate;

    public CheckInRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Set<String> listCheckedInUserIds(String eventId) {
        return new HashSet<>(jdbcTemplate.query(
                "SELECT \"userId\" FROM events.\"ParticipantCheckIn\" WHERE \"eventId\" = ? AND \"checkedIn\" = true",
                (rs, rn) -> rs.getString("userId"),
                eventId
        ));
    }

    public void setCheckIn(String eventId, String userId, boolean checkedIn, String checkedInById) {
        jdbcTemplate.update(
                "INSERT INTO events.\"ParticipantCheckIn\" (\"eventId\", \"userId\", \"checkedIn\", \"checkedInAt\", \"checkedInById\") " +
                        "VALUES (?, ?, ?, CASE WHEN ? THEN NOW() ELSE NULL END, ?) " +
                        "ON CONFLICT (\"eventId\", \"userId\") DO UPDATE SET " +
                        "\"checkedIn\" = EXCLUDED.\"checkedIn\", " +
                        "\"checkedInAt\" = CASE WHEN EXCLUDED.\"checkedIn\" THEN NOW() ELSE NULL END, " +
                        "\"checkedInById\" = EXCLUDED.\"checkedInById\"",
                eventId,
                userId,
                checkedIn,
                checkedIn,
                checkedInById
        );
    }
}

