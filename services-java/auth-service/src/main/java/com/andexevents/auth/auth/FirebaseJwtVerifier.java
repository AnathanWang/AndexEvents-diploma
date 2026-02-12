package com.andexevents.auth.auth;

import com.auth0.jwk.Jwk;
import com.auth0.jwk.JwkProvider;
import com.auth0.jwk.JwkProviderBuilder;
import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.springframework.stereotype.Component;

import java.net.URL;
import java.security.interfaces.RSAPublicKey;
import java.util.concurrent.TimeUnit;

@Component
public class FirebaseJwtVerifier {
    private static final String DEFAULT_JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    private final String projectId;
    private final JwkProvider jwkProvider;

    public FirebaseJwtVerifier(AuthConfigProperties props) {
        this.projectId = props.getFirebaseProjectId();
        if (this.projectId == null || this.projectId.isBlank()) {
            throw new JWTVerificationException("FIREBASE_PROJECT_ID is not configured");
        }

        String jwksUrl = props.getFirebaseJwksUrl();
        if (jwksUrl == null || jwksUrl.isBlank()) {
            jwksUrl = DEFAULT_JWKS_URL;
        }

        try {
            this.jwkProvider = new JwkProviderBuilder(new URL(jwksUrl))
                    .cached(10, 24, TimeUnit.HOURS)
                    .rateLimited(10, 1, TimeUnit.MINUTES)
                    .build();
        } catch (Exception ex) {
            throw new JWTVerificationException("Failed to initialize JWKS provider", ex);
        }
    }

    public DecodedJWT verify(String token) {
        try {
            DecodedJWT decoded = JWT.decode(token);
            String kid = decoded.getKeyId();
            if (kid == null || kid.isBlank()) {
                throw new JWTVerificationException("Missing kid header");
            }

            Jwk jwk = jwkProvider.get(kid);
            Algorithm algorithm = Algorithm.RSA256((RSAPublicKey) jwk.getPublicKey(), null);

            String issuer = "https://securetoken.google.com/" + projectId;
            JWTVerifier verifier = JWT.require(algorithm)
                    .withIssuer(issuer)
                    .withAudience(projectId)
                    .build();

            return verifier.verify(token);
        } catch (JWTVerificationException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new JWTVerificationException("Invalid token", ex);
        }
    }
}
