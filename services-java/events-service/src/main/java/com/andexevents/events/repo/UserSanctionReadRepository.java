package com.andexevents.events.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Arrays;

@Repository
public class UserSanctionReadRepository {
    private final JdbcTemplate jdbcTemplate;

    public UserSanctionReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean hasActiveSanction(String userId, String... types) {
        if (types == null || types.length == 0) {
            return false;
        }

        String placeholders = String.join(",", Arrays.stream(types).map(t -> "CAST(? AS users.\"UserSanctionType\")").toList());

        String sql = """
                SELECT COUNT(*)
                FROM users."UserSanction"
                WHERE "targetUserId" = ?
                  AND "revokedAt" IS NULL
                  AND ("expiresAt" IS NULL OR "expiresAt" > NOW())
                  AND "type" IN (
                """ + placeholders + ")";

        Object[] params = new Object[types.length + 1];
        params[0] = userId;
        System.arraycopy(types, 0, params, 1, types.length);

        Integer count = jdbcTemplate.queryForObject(sql, Integer.class, params);
        return count != null && count > 0;
    }
}
