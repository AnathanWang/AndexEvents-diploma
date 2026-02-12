package com.andexevents.auth;

import com.andexevents.auth.auth.FirebaseJwtVerifier;
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

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AuthServiceIntegrationTest {

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
        r.add("spring.flyway.enabled", () -> "false");
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
        jdbc.execute("CREATE TABLE IF NOT EXISTS \"User\" (id TEXT PRIMARY KEY, \"firebaseUid\" TEXT, \"supabaseUid\" TEXT, email TEXT)");
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS \"User_firebaseUid_key\" ON \"User\"(\"firebaseUid\")");
        jdbc.update("INSERT INTO \"User\" (id, \"firebaseUid\", \"supabaseUid\", email) VALUES (?, ?, ?, ?) ON CONFLICT (id) DO NOTHING",
                "user-1", "firebase-1", "firebase-1", "u1@example.com");

        DecodedJWT jwt1 = jwt("firebase-1", "u1@example.com");
        when(jwtVerifier.verify("t1")).thenReturn(jwt1);
    }

    @Test
    void authMe_returnsUidEmailUserId() {
        ResponseEntity<Map> resp = rest.exchange(
                "/api/auth/me",
                HttpMethod.GET,
                authed("t1"),
                Map.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().get("success")).isEqualTo(true);

        Map data = (Map) resp.getBody().get("data");
        assertThat(data.get("uid")).isEqualTo("firebase-1");
        assertThat(data.get("email")).isEqualTo("u1@example.com");
        assertThat(data.get("userId")).isEqualTo("user-1");
    }

    @Test
    void authValidate_worksSameAsMe() {
        ResponseEntity<Map> resp = rest.exchange(
                "/api/auth/validate",
                HttpMethod.POST,
                authed("t1"),
                Map.class
        );
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().get("success")).isEqualTo(true);
    }

    private HttpEntity<Void> authed(String token) {
        HttpHeaders h = new HttpHeaders();
        h.setBearerAuth(token);
        return new HttpEntity<>(h);
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
