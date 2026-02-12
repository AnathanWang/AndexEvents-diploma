package com.andexevents.events.service;

import com.andexevents.events.model.EventDtos;
import com.andexevents.events.repo.EventRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
public class EventService {
    private final EventRepository repo;

    public EventService(EventRepository repo) {
        this.repo = repo;
    }

    public EventDtos.EventDto create(EventRepository.EventCreateParams p) {
        String id = repo.insertEvent(p);
        return getById(id, null).orElseThrow();
    }

    public List<EventDtos.EventDto> listAllApproved() {
        List<EventDtos.EventDto> out = new ArrayList<>();
        for (EventRepository.EventRow row : repo.listApprovedEvents()) {
            out.add(toDto(row, null, null));
        }
        return out;
    }

    public EventDtos.NearbyEventsResponse listNearby(double lat, double lon, int maxDistanceMeters, String category, int page, int limit, String viewerUserId) {
        EventRepository.NearbyQueryResult qr = repo.listNearbyApprovedEvents(lat, lon, maxDistanceMeters, category, page, limit);

        List<EventDtos.EventDto> events = new ArrayList<>();
        for (EventRepository.NearbyEventRow r : qr.events()) {
            events.add(toDto(r.event(), viewerUserId, new NearbyMeta(r.distance(), r.participantCount(), r.createdBy())));
        }

        int totalPages = (int) Math.ceil(qr.total() / (double) limit);
        return new EventDtos.NearbyEventsResponse(events, new EventDtos.Pagination(page, limit, qr.total(), totalPages));
    }

    public List<EventDtos.EventDto> listUserEvents(String userId) {
        List<EventDtos.EventDto> out = new ArrayList<>();
        for (EventRepository.EventRow row : repo.listUserApprovedEvents(userId)) {
            out.add(toDto(row, null, null));
        }
        return out;
    }

    public Optional<EventDtos.EventDto> getById(String eventId, String viewerUserId) {
        EventRepository.EventRow row = repo.findEventRowById(eventId).orElse(null);
        if (row == null) return Optional.empty();
        return Optional.of(toDto(row, viewerUserId, null));
    }

    public Optional<EventDtos.EventDto> update(String eventId, String userId, EventRepository.EventUpdateParams p) {
        EventRepository.EventRow existing = repo.findEventRowById(eventId).orElse(null);
        if (existing == null) return Optional.empty();
        if (existing.createdById() == null || !existing.createdById().equals(userId)) {
            throw new ForbiddenException("Forbidden: You can only edit your own events");
        }

        return repo.updateEvent(eventId, p).map(r -> toDto(r, userId, null));
    }

    public boolean delete(String eventId, String userId) {
        EventRepository.EventRow existing = repo.findEventRowById(eventId).orElse(null);
        if (existing == null) return false;
        if (existing.createdById() == null || !existing.createdById().equals(userId)) {
            throw new ForbiddenException("Forbidden: You can only delete your own events");
        }
        return repo.deleteEvent(eventId);
    }

    public EventRepository.ParticipantRow participate(String eventId, String userId, String status) {
        EventRepository.EventRow existing = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (!"APPROVED".equalsIgnoreCase(existing.status())) {
            throw new BadRequestException("Cannot participate in unapproved event");
        }
        return repo.upsertParticipation(eventId, userId, status).orElseThrow();
    }

    public EventRepository.ParticipantRow cancelParticipation(String eventId, String userId) {
        return repo.deleteParticipation(eventId, userId).orElse(new EventRepository.ParticipantRow("", userId, eventId, "", null, null));
    }

    public List<EventDtos.ParticipantDto> getParticipants(String eventId) {
        // Ensure event exists
        repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        return repo.findParticipants(eventId);
    }

    private EventDtos.EventDto toDto(EventRepository.EventRow row, String viewerUserId, NearbyMeta nearby) {
        EventDtos.CreatorDto createdBy = nearby != null ? nearby.createdBy() : repo.findCreatorByEventId(row.id()).orElse(null);

        long participantCount = nearby != null ? nearby.participantCount() : repo.countParticipants(row.id());
        List<EventDtos.ParticipantDto> participants = repo.findTopParticipants(row.id(), 5);

        // Node (Prisma) includes `_count: { participants: n }` on non-nearby list/get.
        EventDtos.CountDto count = nearby != null ? null : new EventDtos.CountDto(participantCount);

        boolean isParticipating = false;
        if (viewerUserId != null && !viewerUserId.isBlank()) {
            isParticipating = repo.isParticipating(row.id(), viewerUserId);
        }

        Double distance = nearby != null ? nearby.distance() : null;

        return new EventDtos.EventDto(
                row.id(),
                row.title(),
                row.description(),
                row.category(),
                row.location(),
                row.latitude(),
                row.longitude(),
                row.dateTime(),
                row.endDateTime(),
                row.price(),
                row.imageUrl(),
                row.isOnline(),
                row.status(),
                row.rejectionReason(),
                row.maxParticipants(),
                row.minAge(),
                row.maxAge(),
                row.createdById(),
                createdBy,
                participants,
            count,
                participantCount,
                isParticipating,
                distance
        );
    }

    private record NearbyMeta(double distance, long participantCount, EventDtos.CreatorDto createdBy) {
    }

    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) { super(message); }
    }

    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) { super(message); }
    }

    public static class BadRequestException extends RuntimeException {
        public BadRequestException(String message) { super(message); }
    }
}
