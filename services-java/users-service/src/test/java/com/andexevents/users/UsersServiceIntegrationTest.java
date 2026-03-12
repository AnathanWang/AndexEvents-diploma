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
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class UsersServiceIntegrationTest {

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

    @MockBean
    FirebaseJwtVerifier jwtVerifier;

    @BeforeEach
    void setupVerifier() {
                DecodedJWT jwt1 = jwt("uid-1", "u1@example.com");
                DecodedJWT jwt2 = jwt("uid-2", "u2@example.com");
                DecodedJWT jwt3 = jwt("uid-3", "u1@example.com"); // same email, different uid

                when(jwtVerifier.verify("t1")).thenReturn(jwt1);
                when(jwtVerifier.verify("t2")).thenReturn(jwt2);
                when(jwtVerifier.verify("t3")).thenReturn(jwt3);
    }

    @Test
    void createUser_thenMe_returnsUser() {
        ResponseEntity<Map> created = rest.exchange(
                "/api/users",
                HttpMethod.POST,
                jsonAuthed("t1", Map.of("displayName", "Alice", "photoUrl", "p")),
                Map.class
        );
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(created.getBody()).isNotNull();
        assertThat(created.getBody().get("success")).isEqualTo(true);

        Map data = (Map) created.getBody().get("data");
        assertThat(data.get("email")).isEqualTo("u1@example.com");
        assertThat(data.get("firebaseUid")).isEqualTo("uid-1");

        ResponseEntity<Map> me = rest.exchange(
                "/api/users/me",
                HttpMethod.GET,
                authed("t1"),
                Map.class
        );
        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map meData = (Map) me.getBody().get("data");
        assertThat(meData.get("email")).isEqualTo("u1@example.com");
        assertThat(meData.get("firebaseUid")).isEqualTo("uid-1");
    }

    @Test
    void createUser_duplicateEmailDifferentUid_returns409() {
        ResponseEntity<Map> created1 = rest.exchange(
                "/api/users",
                HttpMethod.POST,
                jsonAuthed("t1", Map.of("displayName", "Alice")),
                Map.class
        );
        assertThat(created1.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Map> created2 = rest.exchange(
                "/api/users",
                HttpMethod.POST,
                jsonAuthed("t3", Map.of("displayName", "Eve")),
                Map.class
        );
        assertThat(created2.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(created2.getBody()).isNotNull();
        assertThat(created2.getBody().get("success")).isEqualTo(false);
    }

    @Test
    void updateLocation_and_updateProfile_and_matches_work() {
        // create current user
        rest.exchange("/api/users", HttpMethod.POST, jsonAuthed("t1", Map.of("displayName", "Alice")), Map.class);
        // create other user
        rest.exchange("/api/users", HttpMethod.POST, jsonAuthed("t2", Map.of("displayName", "Bob")), Map.class);

        // current user onboarding + location
        ResponseEntity<Map> u1Profile = rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                        jsonAuthed("t1", Map.of("isOnboardingCompleted", true, "age", 30)),
                Map.class
        );
        assertThat(u1Profile.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map> u1Loc = rest.exchange(
                "/api/users/me/location",
                HttpMethod.PUT,
                jsonAuthed("t1", Map.of("latitude", 55.751244, "longitude", 37.618423)),
                Map.class
        );
        assertThat(u1Loc.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(u1Loc.getBody().get("message")).isEqualTo("Location updated successfully");

        // other user onboarding + location within radius
        rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed("t2", Map.of("isOnboardingCompleted", true, "age", 25)),
                Map.class
        );
        rest.exchange(
                "/api/users/me/location",
                HttpMethod.PUT,
                jsonAuthed("t2", Map.of("latitude", 55.752000, "longitude", 37.620000)),
                Map.class
        );

        ResponseEntity<Map> matches = rest.exchange(
                "/api/users/matches?radiusKm=5&limit=20",
                HttpMethod.GET,
                authed("t1"),
                Map.class
        );
        assertThat(matches.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(matches.getBody()).isNotNull();
        assertThat(matches.getBody().get("success")).isEqualTo(true);

        List list = (List) matches.getBody().get("data");
        assertThat(list).isNotEmpty();
        assertThat(((Map) list.get(0)).get("email")).isEqualTo("u2@example.com");
    }

    @Test
    void updateProfile_withSocialLinks_returnsUpdatedUser() {
        rest.exchange(
                "/api/users",
                HttpMethod.POST,
                jsonAuthed("t1", Map.of("displayName", "Alice")),
                Map.class
        );

        ResponseEntity<Map> updated = rest.exchange(
                "/api/users/me",
                HttpMethod.PUT,
                jsonAuthed(
                        "t1",
                        Map.of(
                                "bio", "Hello",
                                "socialLinks", Map.of(
                                        "telegram", "https://t.me/alice",
                                        "instagram", "https://instagram.com/alice"
                                )
                        )
                ),
                Map.class
        );

        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updated.getBody()).isNotNull();
        assertThat(updated.getBody().get("success")).isEqualTo(true);

        Map data = (Map) updated.getBody().get("data");
        assertThat(data.get("bio")).isEqualTo("Hello");

        Map socialLinks = (Map) data.get("socialLinks");
        assertThat(socialLinks).isNotNull();
        assertThat(socialLinks.get("telegram")).isEqualTo("https://t.me/alice");
        assertThat(socialLinks.get("instagram")).isEqualTo("https://instagram.com/alice");
    }

    private HttpEntity<Void> authed(String token) {
        HttpHeaders h = new HttpHeaders();
        h.setBearerAuth(token);
        return new HttpEntity<>(h);
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
