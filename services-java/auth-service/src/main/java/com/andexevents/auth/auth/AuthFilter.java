package com.andexevents.auth.auth;

import com.andexevents.auth.api.ApiResponse;
import com.andexevents.auth.repo.UserLookupRepository;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class AuthFilter extends OncePerRequestFilter {
    public static final String ATTR = "andex.auth";

    private final FirebaseJwtVerifier jwtVerifier;
    private final UserLookupRepository userLookupRepository;
    private final ObjectMapper objectMapper;
    private final RequestMatcher required;

    public AuthFilter(
            AuthConfigProperties props,
            FirebaseJwtVerifier jwtVerifier,
            UserLookupRepository userLookupRepository,
            ObjectMapper objectMapper
    ) {
        this.jwtVerifier = jwtVerifier;
        this.userLookupRepository = userLookupRepository;
        this.objectMapper = objectMapper;

        List<RequestMatcher> matchers = props.getRequiredPaths().stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList();

        this.required = matchers.isEmpty() ? request -> false : new OrRequestMatcher(matchers);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !required.matches(request);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            writeUnauthorized(response, "Unauthorized: No token provided");
            return;
        }

        String token = authHeader.substring("Bearer ".length()).trim();
        if (token.isBlank()) {
            writeUnauthorized(response, "Unauthorized: Invalid token format");
            return;
        }

        try {
            DecodedJWT decoded = jwtVerifier.verify(token);
            String uid = decoded.getSubject();
            String email = decoded.getClaim("email").asString();

            if (uid == null || uid.isBlank()) {
                writeUnauthorized(response, "Unauthorized: Invalid token");
                return;
            }

            String userId = userLookupRepository.findUserIdByFirebaseUid(uid).orElse(null);
            request.setAttribute(ATTR, new AuthContext(uid, email, userId));
            filterChain.doFilter(request, response);
        } catch (JWTVerificationException ex) {
            writeUnauthorized(response, "Unauthorized: Invalid token");
        }
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(message));
    }
}
