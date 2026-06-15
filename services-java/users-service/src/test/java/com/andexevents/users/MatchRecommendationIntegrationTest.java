package com.andexevents.users;

import com.andexevents.users.auth.FirebaseJwtVerifier;
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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MatchRecommendationIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(
            DockerImageName.parse("postgis/postgis:16-3.4").asCompatibleSubstituteFor("postgres")
    )
            .withDatabaseName("test")
            .withUsername("postgres")
            .withPassword("postgres")
            .withInitScript("init-db.sql");

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
    JdbcTemplate jdbcTemplate;

    @MockBean
    FirebaseJwtVerifier jwtVerifier;

    @BeforeEach
    void resetDatabase() {
        jdbcTemplate.update("DELETE FROM events.\"Participant\"");
        jdbcTemplate.update("DELETE FROM events.\"Event\"");
        jdbcTemplate.update("DELETE FROM \"Match\"");
        jdbcTemplate.update("DELETE FROM users.\"UserBlock\"");
        jdbcTemplate.update("DELETE FROM users.\"User\"");
    }

    @BeforeEach
    void setupVerifier() {
        DecodedJWT aliceJwt = buildJwt("uid-alice", "alice@example.com");
        DecodedJWT bobJwt = buildJwt("uid-bob", "bob@example.com");
        DecodedJWT carolJwt = buildJwt("uid-carol", "carol@example.com");
        DecodedJWT daveJwt = buildJwt("uid-dave", "dave@example.com");

        when(jwtVerifier.verify("alice")).thenReturn(aliceJwt);
        when(jwtVerifier.verify("bob")).thenReturn(bobJwt);
        when(jwtVerifier.verify("carol")).thenReturn(carolJwt);
        when(jwtVerifier.verify("dave")).thenReturn(daveJwt);
    }

    @Test
    void matches_respectsConfiguredAgeRange() {
        seedUser("alice", "alice@example.com", "uid-alice");
        seedUser("bob", "bob@example.com", "uid-bob");
        seedUser("carol", "carol@example.com", "uid-carol");

        completeOnboarding("alice", 30, List.of("Music"), 55.751244, 37.618423);
        completeOnboarding("bob", 25, List.of("Music"), 55.751500, 37.618600);
        completeOnboarding("carol", 40, List.of("Music"), 55.751600, 37.618700);

        putProfile("alice", Map.of(
                "minAge", 20,
                "maxAge", 35
        ));

        List<Map<String, Object>> matches = getMatches("alice");
        assertThat(matches).extracting(m -> m.get("email"))
                .contains("bob@example.com")
                .doesNotContain("carol@example.com");
    }

    @Test
    void matches_excludesUsersWithExistingGlobalAction() {
        String aliceId = seedUser("alice", "alice@example.com", "uid-alice");
        String bobId = seedUser("bob", "bob@example.com", "uid-bob");

        completeOnboarding("alice", 30, List.of("Music"), 55.751244, 37.618423);
        completeOnboarding("bob", 27, List.of("Music"), 55.751500, 37.618600);

        jdbcTemplate.update(
                """
                INSERT INTO "Match" (
                  id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "createdAt", "updatedAt"
                ) VALUES (?, ?, ?, NULL, 'LIKE', NULL, false, NOW(), NOW())
                """,
                UUID.randomUUID().toString(),
                aliceId,
                bobId
        );

        List<Map<String, Object>> matches = getMatches("alice");
        assertThat(matches).extracting(m -> m.get("email"))
                .doesNotContain("bob@example.com");
    }

    @Test
    void matches_prioritizesSharedGoingEventsAndRicherProfiles() {
        String aliceId = seedUser("alice", "alice@example.com", "uid-alice");
        String bobId = seedUser("bob", "bob@example.com", "uid-bob");
        String daveId = seedUser("dave", "dave@example.com", "uid-dave");

        completeOnboarding("alice", 28, List.of("Music", "Sport"), 55.751244, 37.618423);
        completeOnboarding("bob", 26, List.of("Music", "Sport", "Art"), 55.751800, 37.619000);
        completeOnboarding("dave", 27, List.of("IT"), 55.751500, 37.618600);

        jdbcTemplate.update(
                "UPDATE users.\"User\" SET \"photoUrl\" = ?, bio = ?, interests = ?::text[] WHERE id = ?",
                "https://example.com/bob.jpg",
                "Bob bio",
                new String[]{"Music", "Sport", "Art"},
                bobId
        );
        jdbcTemplate.update(
                "UPDATE users.\"User\" SET interests = ?::text[] WHERE id = ?",
                new String[]{"IT"},
                daveId
        );

        String eventId = "event-shared-1";
        jdbcTemplate.update(
                "INSERT INTO events.\"Event\" (id, \"createdById\", status) VALUES (?, ?, 'APPROVED'::events.\"EventStatus\")",
                eventId,
                aliceId
        );
        insertGoingParticipant("part-a", aliceId, eventId);
        insertGoingParticipant("part-b", bobId, eventId);

        List<Map<String, Object>> matches = getMatches("alice");
        assertThat(matches).isNotEmpty();
        assertThat(matches.get(0).get("email")).isEqualTo("bob@example.com");
    }

    @Test
    void updateProfile_persistsPrivacyAndCanClearAgeRange() {
        seedUser("alice", "alice@example.com", "uid-alice");

        ResponseEntity<Map> updated = rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed("alice", Map.of(
                        "showInMatches", false,
                        "incognitoMode", true,
                        "minAge", 22,
                        "maxAge", 34
                )),
                Map.class
        );
        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);

        Map data = (Map) updated.getBody().get("data");
        assertThat(data.get("showInMatches")).isEqualTo(false);
        assertThat(data.get("incognitoMode")).isEqualTo(true);
        assertThat(data.get("minAge")).isEqualTo(22);
        assertThat(data.get("maxAge")).isEqualTo(34);

        ResponseEntity<Map> cleared = rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed("alice", Map.of(
                        "clearMinAge", true,
                        "clearMaxAge", true
                )),
                Map.class
        );
        assertThat(cleared.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map clearedData = (Map) cleared.getBody().get("data");
        assertThat(clearedData.get("minAge")).isNull();
        assertThat(clearedData.get("maxAge")).isNull();
    }

    private String seedUser(String token, String email, String firebaseUid) {
        rest.exchange(
                "/api/users",
                HttpMethod.POST,
                jsonAuthed(token, Map.of("displayName", email.split("@")[0])),
                Map.class
        );
        return jdbcTemplate.queryForObject(
                "SELECT id FROM users.\"User\" WHERE email = ?",
                String.class,
                email
        );
    }

    private void completeOnboarding(
            String token,
            int age,
            List<String> interests,
            double lat,
            double lon
    ) {
        rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed(token, Map.of(
                        "isOnboardingCompleted", true,
                        "age", age,
                        "interests", interests
                )),
                Map.class
        );
        rest.exchange(
                "/api/users/me/location",
                HttpMethod.PUT,
                jsonAuthed(token, Map.of("latitude", lat, "longitude", lon)),
                Map.class
        );
    }

    private void putProfile(String token, Map<String, Object> body) {
        ResponseEntity<Map> response = rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed(token, body),
                Map.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> getMatches(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/api/users/matches?radiusKm=10&limit=20",
                HttpMethod.GET,
                authed(token),
                Map.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (List<Map<String, Object>>) response.getBody().get("data");
    }

    private void insertGoingParticipant(String id, String userId, String eventId) {
        jdbcTemplate.update(
                """
                INSERT INTO events."Participant" (id, "userId", "eventId", status, "joinedAt", "updatedAt")
                VALUES (?, ?, ?, 'GOING'::events."ParticipantStatus", NOW(), NOW())
                """,
                id,
                userId,
                eventId
        );
    }

    private HttpEntity<Void> authed(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return new HttpEntity<>(headers);
    }

    private HttpEntity<Map<String, Object>> jsonAuthed(String token, Map<String, Object> body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(token);
        return new HttpEntity<>(body, headers);
    }

    private DecodedJWT buildJwt(String sub, String email) {
        DecodedJWT decoded = mock(DecodedJWT.class);
        when(decoded.getSubject()).thenReturn(sub);

        Claim emailClaim = mock(Claim.class);
        when(emailClaim.asString()).thenReturn(email);
        when(decoded.getClaim("email")).thenReturn(emailClaim);

        return decoded;
    }
}
