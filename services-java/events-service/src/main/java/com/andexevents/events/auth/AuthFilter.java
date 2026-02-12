package com.andexevents.events.auth;

import com.andexevents.events.api.ApiResponse;
import com.andexevents.events.repo.UserLookupRepository;
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
    private final RequestMatcher optional;

    public AuthFilter(
            AuthConfigProperties props,
            FirebaseJwtVerifier jwtVerifier,
            UserLookupRepository userLookupRepository,
            ObjectMapper objectMapper
    ) {
        this.jwtVerifier = jwtVerifier;
        this.userLookupRepository = userLookupRepository;
        this.objectMapper = objectMapper;

        this.required = toMatcher(props.getRequiredPaths());
        this.optional = toMatcher(props.getOptionalPaths());
    }

    private RequestMatcher toMatcher(List<AuthConfigProperties.PathRule> rules) {
        List<RequestMatcher> matchers = rules.stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList();
        return matchers.isEmpty() ? request -> false : new OrRequestMatcher(matchers);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !(required.matches(request) || optional.matches(request));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        boolean requireAuth = required.matches(request);

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: No token provided");
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring("Bearer ".length()).trim();
        if (token.isBlank()) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: Invalid token format");
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        try {
            DecodedJWT decoded = jwtVerifier.verify(token);
            String uid = decoded.getSubject();
            String email = decoded.getClaim("email").asString();

            if (uid != null && !uid.isBlank()) {
                String userId = userLookupRepository.findUserIdByFirebaseUid(uid).orElse(null);
                request.setAttribute(ATTR, new AuthContext(uid, email, userId));
            }

            filterChain.doFilter(request, response);
        } catch (JWTVerificationException ex) {
            if (requireAuth) {
                writeUnauthorized(response, "Unauthorized: Invalid token");
                return;
            }
            // optional auth: ignore invalid token (Node behavior)
            filterChain.doFilter(request, response);
        }
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(message));
    }
}
