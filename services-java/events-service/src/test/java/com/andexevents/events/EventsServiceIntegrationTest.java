package com.andexevents.events;

import com.andexevents.events.auth.FirebaseJwtVerifier;
import com.auth0.jwt.interfaces.Claim;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class EventsServiceIntegrationTest {

    @Container
        static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(
            DockerImageName.parse("postgis/postgis:16-3.4").asCompatibleSubstituteFor("postgres")
        )
            .withDatabaseName("test")
            .withUsername("postgres")
            .withPassword("postgres");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
        r.add("spring.flyway.enabled", () -> "true");
        r.add("app.auth.firebaseProjectId", () -> "test-project");
    }

    @Autowired
    TestRestTemplate rest;

    @Autowired
    JdbcTemplate jdbc;

    @MockBean
    FirebaseJwtVerifier jwtVerifier;

    @BeforeEach
    void setup() {
        // Minimal shared User table for joins and lookups.
        jdbc.execute("CREATE SCHEMA IF NOT EXISTS users");
        jdbc.execute("DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'UserSanctionType' AND typnamespace = 'users'::regnamespace) THEN " +
                "CREATE TYPE users.\"UserSanctionType\" AS ENUM ('WARNING', 'MUTE', 'EVENT_CREATE_BAN', 'FULL_BAN'); END IF; END $$;");
        jdbc.execute("CREATE TABLE IF NOT EXISTS users.\"User\" (id TEXT PRIMARY KEY, \"firebaseUid\" TEXT, \"supabaseUid\" TEXT, email TEXT, \"displayName\" TEXT, \"photoUrl\" TEXT)");
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS \"User_firebaseUid_key\" ON users.\"User\"(\"firebaseUid\")");

        // Added UserSanction table for test stability (used by UserSanctionGuardService)
        jdbc.execute("CREATE TABLE IF NOT EXISTS users.\"UserSanction\" (" +
                "id TEXT PRIMARY KEY, \"targetUserId\" TEXT REFERENCES users.\"User\"(id), " +
                "\"createdByUserId\" TEXT, type users.\"UserSanctionType\", reason TEXT, \"expiresAt\" TIMESTAMP(3), " +
                "\"revokedAt\" TIMESTAMP(3), \"revokedByUserId\" TEXT, " +
                "\"createdAt\" TIMESTAMP(3), \"updatedAt\" TIMESTAMP(3))");

            DecodedJWT jwt1 = jwt("firebase-1", "u1@example.com");
            DecodedJWT jwt2 = jwt("firebase-2", "u2@example.com");

            when(jwtVerifier.verify("u1")).thenReturn(jwt1);
            when(jwtVerifier.verify("u2")).thenReturn(jwt2);

        ensureUser("user-1", "firebase-1", "u1@example.com", "Alice");
        ensureUser("user-2", "firebase-2", "u2@example.com", "Bob");
    }

    @Test
    void createEvent_list_get_participate_participants_flow() {
        ResponseEntity<Map> created = rest.exchange(
                "/api/events",
                HttpMethod.POST,
                jsonAuthed("u1", Map.of(
                        "title", "T",
                        "description", "D",
                        "category", "C",
                        "location", "L",
                        "latitude", 55.751244,
                        "longitude", 37.618423,
                        "dateTime", "2027-02-09T12:00:00Z",
                        "price", 0,
                        "imageUrl", "",
                        "isOnline", false
                )),
                Map.class
        );
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        Map createdData = (Map) created.getBody().get("data");
        String eventId = (String) createdData.get("id");
        assertThat(eventId).isNotBlank();

        // Manual approval for listing
        jdbc.update("UPDATE events.\"Event\" SET status = 'APPROVED' WHERE id = ?", eventId);

        // list all
        ResponseEntity<Map> list = rest.exchange("/api/events", HttpMethod.GET, new HttpEntity<>(new HttpHeaders()), Map.class);
        assertThat(list.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map listData = (Map) list.getBody().get("data");
        List events = (List) listData.get("events");
        assertThat(events).isNotEmpty();
        Map first = (Map) events.get(0);
        assertThat(first.get("id")).isEqualTo(eventId);
        assertThat(first).containsKey("participantCount");
        assertThat(first).containsKey("_count");

        // get by id (optional auth not required)
        ResponseEntity<Map> get = rest.exchange("/api/events/" + eventId, HttpMethod.GET, new HttpEntity<>(new HttpHeaders()), Map.class);
        assertThat(get.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map getData = (Map) get.getBody().get("data");
        assertThat(getData.get("isParticipating")).isEqualTo(false);

        // participate as user-2
        ResponseEntity<Map> participate = rest.exchange(
                "/api/events/" + eventId + "/participate",
                HttpMethod.POST,
                jsonAuthed("u2", Map.of("status", "GOING")),
                Map.class
        );
        assertThat(participate.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(participate.getBody().get("message")).isEqualTo("Participation status updated");

        // participants list should include user-2 (no cap)
        ResponseEntity<Map> participants = rest.exchange(
                "/api/events/" + eventId + "/participants",
                HttpMethod.GET,
                new HttpEntity<>(new HttpHeaders()),
                Map.class
        );
        assertThat(participants.getStatusCode()).isEqualTo(HttpStatus.OK);
        List plist = (List) participants.getBody().get("data");
        assertThat(plist).isNotEmpty();
        Map p0 = (Map) plist.get(0);
        assertThat(p0.get("eventId")).isEqualTo(eventId);
        Map userPreview = (Map) p0.get("user");
        assertThat(userPreview.get("email")).isEqualTo("u2@example.com");
    }

        @Test
        void userParticipatedEvents_returnsRealParticipatedEvents() {
        ResponseEntity<Map> created = rest.exchange(
            "/api/events",
            HttpMethod.POST,
            jsonAuthed("u1", Map.of(
                "title", "Participated Event",
                "description", "Desc",
                "category", "C",
                "location", "L",
                "latitude", 55.751244,
                "longitude", 37.618423,
                "dateTime", "2026-02-09T12:00:00Z",
                "price", 0,
                "imageUrl", "",
                "isOnline", false
            )),
            Map.class
        );
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        Map createdData = (Map) created.getBody().get("data");
        String eventId = (String) createdData.get("id");

        // Manual approval for listing
        jdbc.update("UPDATE events.\"Event\" SET status = 'APPROVED' WHERE id = ?", eventId);

        ResponseEntity<Map> participate = rest.exchange(
            "/api/events/" + eventId + "/participate",
            HttpMethod.POST,
            jsonAuthed("u2", Map.of("status", "GOING")),
            Map.class
        );
        assertThat(participate.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map> participated = rest.exchange(
            "/api/events/user/user-2/participated",
            HttpMethod.GET,
            new HttpEntity<>(new HttpHeaders()),
            Map.class
        );

        assertThat(participated.getStatusCode()).isEqualTo(HttpStatus.OK);
        List rows = (List) participated.getBody().get("data");
        assertThat(rows).isNotEmpty();
        Map first = (Map) rows.get(0);
        assertThat(first.get("id")).isEqualTo(eventId);
        assertThat(first.get("title")).isEqualTo("Participated Event");
        }

    private void ensureUser(String id, String firebaseUid, String email, String displayName) {
        jdbc.update(
            "INSERT INTO users.\"User\" (id, \"firebaseUid\", \"supabaseUid\", email, \"displayName\", \"photoUrl\") VALUES (?, ?, ?, ?, ?, ?) " +
                        "ON CONFLICT (id) DO NOTHING",
                id,
                firebaseUid,
                firebaseUid,
                email,
                displayName,
                ""
        );
    }

    private HttpEntity<Map<String, Object>> jsonAuthed(String token, Map<String, Object> body) {
        HttpHeaders h = new HttpHeaders();
        h.setContentType(MediaType.APPLICATION_JSON);
        h.setBearerAuth(token);
        return new HttpEntity<>(body, h);
    }

    private DecodedJWT jwt(String sub, String email) {
        DecodedJWT decoded = mock(DecodedJWT.class);
        when(decoded.getSubject()).thenReturn(sub);

        Claim emailClaim = mock(Claim.class);
        when(emailClaim.asString()).thenReturn(email);
        when(decoded.getClaim("email")).thenReturn(emailClaim);

        return decoded;
    }
}
