package com.andexevents.events.service;

import com.andexevents.events.repo.UserRoleReadRepository;
import org.springframework.stereotype.Service;

@Service
public class ModerationAccessService {
    private final UserRoleReadRepository userRoleReadRepository;

    public ModerationAccessService(UserRoleReadRepository userRoleReadRepository) {
        this.userRoleReadRepository = userRoleReadRepository;
    }

    public boolean canModerate(String userId) {
        final String role = userRoleReadRepository.findRoleByUserId(userId);
        if (role == null) return false;
        final String normalized = role.trim().toUpperCase();
        return "ADMIN".equals(normalized) || "MODERATOR".equals(normalized);
    }
}

