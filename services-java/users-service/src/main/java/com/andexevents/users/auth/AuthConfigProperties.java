package com.andexevents.users.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.ArrayList;
import java.util.List;

@ConfigurationProperties(prefix = "app.auth")
public class AuthConfigProperties {
    private String firebaseProjectId;
    private String firebaseJwksUrl;
    /**
     * If true: any request that is not explicitly public requires a valid Bearer token.
     * Safer for production because "new endpoint forgot to secure" won't become public.
     *
     * Default false to preserve current dev behavior.
     */
    private boolean defaultRequireAuth = false;
    private List<RequiredPath> requiredPaths = new ArrayList<>();
    private List<RequiredPath> publicPaths = new ArrayList<>();

    public String getFirebaseProjectId() {
        return firebaseProjectId;
    }

    public void setFirebaseProjectId(String firebaseProjectId) {
        this.firebaseProjectId = firebaseProjectId;
    }

    public String getFirebaseJwksUrl() {
        return firebaseJwksUrl;
    }

    public void setFirebaseJwksUrl(String firebaseJwksUrl) {
        this.firebaseJwksUrl = firebaseJwksUrl;
    }

    public boolean isDefaultRequireAuth() {
        return defaultRequireAuth;
    }

    public void setDefaultRequireAuth(boolean defaultRequireAuth) {
        this.defaultRequireAuth = defaultRequireAuth;
    }

    public List<RequiredPath> getRequiredPaths() {
        return requiredPaths;
    }

    public void setRequiredPaths(List<RequiredPath> requiredPaths) {
        this.requiredPaths = requiredPaths;
    }

    public List<RequiredPath> getPublicPaths() {
        return publicPaths;
    }

    public void setPublicPaths(List<RequiredPath> publicPaths) {
        this.publicPaths = publicPaths;
    }

    public static class RequiredPath {
        private String method;
        private String pattern;

        public String getMethod() {
            return method;
        }

        public void setMethod(String method) {
            this.method = method;
        }

        public String getPattern() {
            return pattern;
        }

        public void setPattern(String pattern) {
            this.pattern = pattern;
        }
    }
}
