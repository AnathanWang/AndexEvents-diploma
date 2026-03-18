package com.andexevents.users.auth;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class SupabaseJwtVerifier {
    private final String secret;

    public SupabaseJwtVerifier(@Value("${app.auth.supabaseJwtSecret:}") String secret) {
        this.secret = secret == null ? "" : secret;
    }

    public DecodedJWT verify(String token) throws JWTVerificationException {
        if (secret.isBlank()) {
            throw new JWTVerificationException("SUPABASE_JWT_SECRET is not configured");
        }
        Algorithm algorithm = Algorithm.HMAC256(secret);
        JWTVerifier verifier = JWT.require(algorithm).build();
        return verifier.verify(token);
    }
}
