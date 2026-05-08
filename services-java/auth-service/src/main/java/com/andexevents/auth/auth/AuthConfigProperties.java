package com.andexevents.auth.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.ArrayList;
import java.util.List;

@ConfigurationProperties(prefix = "app.auth")
public class AuthConfigProperties {
    private String firebaseProjectId;
    private String firebaseJwksUrl;
    private boolean defaultRequireAuth = false;
    private List<PathRule> requiredPaths = new ArrayList<>();
    private List<PathRule> publicPaths = new ArrayList<>();

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

    public List<PathRule> getRequiredPaths() {
        return requiredPaths;
    }

    public void setRequiredPaths(List<PathRule> requiredPaths) {
        this.requiredPaths = requiredPaths;
    }

    public List<PathRule> getPublicPaths() {
        return publicPaths;
    }

    public void setPublicPaths(List<PathRule> publicPaths) {
        this.publicPaths = publicPaths;
    }

    public static class PathRule {
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
