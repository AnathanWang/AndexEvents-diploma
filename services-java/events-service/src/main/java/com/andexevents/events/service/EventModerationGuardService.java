package com.andexevents.events.service;

import com.andexevents.events.model.EventSanctionType;
import com.andexevents.events.repo.EventReportReadRepository;
import com.andexevents.events.repo.EventSanctionRepository;
import org.springframework.stereotype.Service;

@Service
public class EventModerationGuardService {
    private final EventReportReadRepository eventReportReadRepository;
    private final EventSanctionRepository eventSanctionRepository;

    public EventModerationGuardService(
            EventReportReadRepository eventReportReadRepository,
            EventSanctionRepository eventSanctionRepository
    ) {
        this.eventReportReadRepository = eventReportReadRepository;
        this.eventSanctionRepository = eventSanctionRepository;
    }

    public void assertCanParticipate(String eventId) {
        if (eventSanctionRepository.hasActive(eventId, EventSanctionType.FREEZE_PARTICIPATION)) {
            throw new ForbiddenException("Участие временно ограничено санкцией события");
        }

        boolean hasPending = eventReportReadRepository.hasPendingEventReports(eventId);
        if (hasPending) {
            throw new ForbiddenException("Событие на модерации: участие временно ограничено");
        }
    }

    public void assertCanEdit(String eventId) {
        if (eventSanctionRepository.hasActive(eventId, EventSanctionType.LIMIT_EDITS)) {
            throw new ForbiddenException("Редактирование события временно ограничено санкцией");
        }
    }

    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) {
            super(message);
        }
    }
}

