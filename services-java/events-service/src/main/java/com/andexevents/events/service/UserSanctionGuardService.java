package com.andexevents.events.service;

import com.andexevents.events.repo.UserSanctionReadRepository;
import org.springframework.stereotype.Service;

@Service
public class UserSanctionGuardService {
    private final UserSanctionReadRepository sanctionReadRepository;

    public UserSanctionGuardService(UserSanctionReadRepository sanctionReadRepository) {
        this.sanctionReadRepository = sanctionReadRepository;
    }

    public void assertCanCreateEvent(String userId) {
        boolean blocked = sanctionReadRepository.hasActiveSanction(
                userId,
                "FULL_BAN",
                "EVENT_CREATE_BAN"
        );

        if (blocked) {
            throw new ForbiddenException("Your account is restricted from creating events");
        }
    }

    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) {
            super(message);
        }
    }
}
