package com.andexevents.users.auth;

import com.andexevents.users.api.ApiResponse;
import com.andexevents.users.repo.UserLookupRepository;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Component
public class AuthFilter extends OncePerRequestFilter {
    public static final String ATTR = "andex.auth";

    private final FirebaseJwtVerifier jwtVerifier;
    private final UserLookupRepository userLookupRepository;
    private final ObjectMapper objectMapper;
    private final RequestMatcher required;
    private final RequestMatcher publicMatcher;
    private final boolean defaultRequireAuth;

    public AuthFilter(
            AuthConfigProperties props,
            FirebaseJwtVerifier jwtVerifier,
            UserLookupRepository userLookupRepository,
            ObjectMapper objectMapper
    ) {
        this.jwtVerifier = jwtVerifier;
        this.userLookupRepository = userLookupRepository;
        this.objectMapper = objectMapper;
        this.defaultRequireAuth = props.isDefaultRequireAuth();

        List<RequestMatcher> requiredMatchers = props.getRequiredPaths().stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList();

        this.required = requiredMatchers.isEmpty() ? request -> false : new OrRequestMatcher(requiredMatchers);

        List<RequestMatcher> publicMatchers = new ArrayList<>();
        // Explicit public paths from config
        publicMatchers.addAll(props.getPublicPaths().stream()
                .map(p -> new AntPathRequestMatcher(p.getPattern(), p.getMethod()))
                .map(m -> (RequestMatcher) m)
                .toList());
        // Always allow basic service introspection
        publicMatchers.add(new AntPathRequestMatcher("/health", null));
        publicMatchers.add(new AntPathRequestMatcher("/actuator/**", null));
        publicMatchers.add(new AntPathRequestMatcher("/swagger-ui/**", null));
        publicMatchers.add(new AntPathRequestMatcher("/v3/api-docs/**", null));

        this.publicMatcher = publicMatchers.isEmpty() ? request -> false : new OrRequestMatcher(publicMatchers);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        // In dev mode (defaultRequireAuth=false) preserve old behavior:
        // only filter requests that are explicitly listed as required.
        if (!defaultRequireAuth) {
            return !required.matches(request);
        }
        // In prod mode (defaultRequireAuth=true) filter everything except explicitly public routes.
        return publicMatcher.matches(request);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        boolean requireAuth = defaultRequireAuth || required.matches(request);
        boolean isPublic = publicMatcher.matches(request);

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            if (requireAuth && !isPublic) {
                writeUnauthorized(response, "Unauthorized: No token provided");
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring("Bearer ".length()).trim();
        if (token.isBlank()) {
            if (requireAuth && !isPublic) {
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

            if (uid == null || uid.isBlank()) {
                if (requireAuth && !isPublic) {
                    writeUnauthorized(response, "Unauthorized: Invalid token");
                    return;
                }
                filterChain.doFilter(request, response);
                return;
            }

            String userId = null;

            if (email != null && !email.isBlank()) {
                // Prefer exact uid+email match first, then email fallback.
                // This avoids binding to a stale uid row when identity data was migrated.
                userId = userLookupRepository.findUserIdByFirebaseUidAndEmail(uid, email).orElse(null);
                if (userId == null) {
                    userId = userLookupRepository.findUserIdByEmail(email).orElse(null);
                }
            }

            if (userId == null) {
                userId = userLookupRepository.findUserIdByFirebaseUid(uid).orElse(null);
            }
            AuthContext auth = new AuthContext(uid, email, userId);
            request.setAttribute(ATTR, auth);
            filterChain.doFilter(request, response);
        } catch (JWTVerificationException ex) {
            if (requireAuth && !isPublic) {
                writeUnauthorized(response, "Unauthorized: Invalid token");
                return;
            }
            // Public endpoints: ignore invalid token.
            filterChain.doFilter(request, response);
        }
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(message));
    }
}
