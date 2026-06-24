package com.andexevents.users.scheduler;

import com.andexevents.users.repo.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class DemoBotLocationKeepAliveScheduler {
    private static final Logger logger = LoggerFactory.getLogger(DemoBotLocationKeepAliveScheduler.class);

    private final UserRepository userRepository;

    public DemoBotLocationKeepAliveScheduler(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Scheduled(fixedRate = 120_000, initialDelay = 15_000)
    public void refreshDemoBotLocations() {
        int updated = userRepository.refreshDemoBotLocationTimestamps();
        if (updated > 0) {
            logger.debug("Refreshed demo bot map locations: {}", updated);
        }
    }
}
