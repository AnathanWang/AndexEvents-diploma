package com.andexevents.events.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.ArrayList;
import java.util.List;

@ConfigurationProperties(prefix = "app.auth")
public class AuthConfigProperties {
    private String firebaseProjectId;
    private String firebaseJwksUrl;
    private List<PathRule> requiredPaths = new ArrayList<>();
    private List<PathRule> optionalPaths = new ArrayList<>();

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

    public List<PathRule> getRequiredPaths() {
        return requiredPaths;
    }

    public void setRequiredPaths(List<PathRule> requiredPaths) {
        this.requiredPaths = requiredPaths;
    }

    public List<PathRule> getOptionalPaths() {
        return optionalPaths;
    }

    public void setOptionalPaths(List<PathRule> optionalPaths) {
        this.optionalPaths = optionalPaths;
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
