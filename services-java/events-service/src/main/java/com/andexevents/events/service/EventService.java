package com.andexevents.events.service;

import com.andexevents.events.model.EventDtos;
import com.andexevents.events.repo.EventRepository;
import com.andexevents.events.repo.CheckInRepository;
import com.andexevents.events.repo.EventParticipantBanRepository;
import com.andexevents.events.repo.OrganizerBlockRepository;
import com.andexevents.events.repo.WaitlistRepository;
import com.andexevents.events.repo.RatingRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;

@Service
public class EventService {
    private final EventRepository repo;
    private final RatingRepository ratingRepo;
    private final EventModerationGuardService eventModerationGuardService;
    private final EventParticipantBanRepository eventParticipantBanRepository;
    private final OrganizerBlockRepository organizerBlockRepository;
    private final WaitlistRepository waitlistRepository;
    private final CheckInRepository checkInRepository;

    public EventService(
            EventRepository repo,
            RatingRepository ratingRepo,
            EventModerationGuardService eventModerationGuardService,
            EventParticipantBanRepository eventParticipantBanRepository,
            OrganizerBlockRepository organizerBlockRepository,
            WaitlistRepository waitlistRepository,
            CheckInRepository checkInRepository
    ) {
        this.repo = repo;
        this.ratingRepo = ratingRepo;
        this.eventModerationGuardService = eventModerationGuardService;
        this.eventParticipantBanRepository = eventParticipantBanRepository;
        this.organizerBlockRepository = organizerBlockRepository;
        this.waitlistRepository = waitlistRepository;
        this.checkInRepository = checkInRepository;
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

    public List<EventDtos.EventDto> listAllApprovedForModeration(String moderatorUserId) {
        if (moderatorUserId == null || moderatorUserId.isBlank()) {
            throw new ForbiddenException("Unauthorized");
        }
        List<EventDtos.EventDto> out = new ArrayList<>();
        for (EventRepository.EventRow row : repo.listApprovedEventsIncludingHidden()) {
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

    public List<EventDtos.EventDto> listUserParticipatedEvents(String userId) {
        List<EventDtos.EventDto> out = new ArrayList<>();
        for (EventRepository.EventRow row : repo.listUserParticipatedApprovedEvents(userId)) {
            out.add(toDto(row, userId, null));
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

        eventModerationGuardService.assertCanEdit(eventId);
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

    public boolean deleteAsModerator(String eventId) {
        EventRepository.EventRow existing = repo.findEventRowById(eventId).orElse(null);
        if (existing == null) return false;
        return repo.deleteEvent(eventId);
    }

    public EventRepository.ParticipantRow participate(String eventId, String userId, String status) {
        EventRepository.EventRow existing = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (!"APPROVED".equalsIgnoreCase(existing.status())) {
            throw new BadRequestException("Cannot participate in unapproved event");
        }

        if (eventParticipantBanRepository.isBanned(eventId, userId)) {
            throw new ForbiddenException("Вы заблокированы для участия в этом событии");
        }
        if (existing.createdById() != null && organizerBlockRepository.isBlocked(existing.createdById(), userId)) {
            throw new ForbiddenException("Организатор заблокировал вас");
        }

        if ("GOING".equalsIgnoreCase(status) && existing.maxParticipants() != null) {
            long going = repo.countGoingParticipants(eventId);
            if (going >= existing.maxParticipants()) {
                waitlistRepository.upsertPending(eventId, userId);
                throw new BadRequestException("Лимит участников достигнут. Вы добавлены в лист ожидания.");
            }
        }

        eventModerationGuardService.assertCanParticipate(eventId);
        return repo.upsertParticipation(eventId, userId, status).orElseThrow();
    }

    public EventRepository.ParticipantRow cancelParticipation(String eventId, String userId) {
        return repo.deleteParticipation(eventId, userId).orElse(new EventRepository.ParticipantRow("", userId, eventId, "", null, null));
    }

    public List<EventDtos.ParticipantDto> getParticipants(String eventId) {
        repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        return repo.findParticipants(eventId);
    }

    public record ManageParticipant(EventDtos.ParticipantDto participant, boolean checkedIn) {
    }

    public List<ManageParticipant> getParticipantsForManage(String eventId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        List<EventDtos.ParticipantDto> participants = repo.findParticipants(eventId);
        var checked = checkInRepository.listCheckedInUserIds(eventId);
        List<ManageParticipant> out = new ArrayList<>();
        for (EventDtos.ParticipantDto p : participants) {
            out.add(new ManageParticipant(p, checked.contains(p.userId())));
        }
        return out;
    }

    public void kickParticipant(String eventId, String targetUserId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        repo.deleteParticipation(eventId, targetUserId);
    }

    public void setCheckIn(String eventId, String targetUserId, boolean checkedIn, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        checkInRepository.setCheckIn(eventId, targetUserId, checkedIn, organizerUserId);
    }

    public void banUserForEvent(String eventId, String targetUserId, String reason, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        eventParticipantBanRepository.upsertBan(eventId, targetUserId, reason, organizerUserId);
    }

    public void unbanUserForEvent(String eventId, String targetUserId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        eventParticipantBanRepository.deleteBan(eventId, targetUserId);
    }

    public List<WaitlistRepository.WaitlistEntryRow> listWaitlist(String eventId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        return waitlistRepository.listByEvent(eventId);
    }

    public void approveWaitlist(String eventId, String targetUserId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        if (event.maxParticipants() != null) {
            long going = repo.countGoingParticipants(eventId);
            if (going >= event.maxParticipants()) {
                throw new BadRequestException("Лимит участников уже заполнен");
            }
        }
        waitlistRepository.approve(eventId, targetUserId);
        repo.upsertParticipation(eventId, targetUserId, "GOING");
    }

    public void rejectWaitlist(String eventId, String targetUserId, String organizerUserId) {
        EventRepository.EventRow event = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        if (event.createdById() == null || !event.createdById().equals(organizerUserId)) {
            throw new ForbiddenException("Forbidden");
        }
        waitlistRepository.reject(eventId, targetUserId);
    }

    public void blockUserGlobally(String organizerUserId, String blockedUserId, String reason) {
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        organizerBlockRepository.upsertBlock(organizerUserId, blockedUserId, reason);
    }

    public void unblockUserGlobally(String organizerUserId, String blockedUserId) {
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        organizerBlockRepository.deleteBlock(organizerUserId, blockedUserId);
    }

    public List<EventDtos.UserPreviewDto> listGlobalBlockedUsers(String organizerUserId) {
        if (organizerUserId == null || organizerUserId.isBlank()) throw new ForbiddenException("Unauthorized");
        return organizerBlockRepository.listBlockedUsers(organizerUserId);
    }

    // ── Rating ─────────────────────────────────────────────────────────────

    public EventDtos.RatingDto rateEvent(String eventId, String userId, int rating, String comment) {
        repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));

        if (!ratingRepo.isEventEnded(eventId)) {
            throw new BadRequestException("Cannot rate an event that has not ended yet");
        }
        if (!ratingRepo.isParticipant(eventId, userId)) {
            throw new ForbiddenException("Only participants can rate an event");
        }
        if (rating < 1 || rating > 5) {
            throw new BadRequestException("Rating must be between 1 and 5");
        }

        return ratingRepo.upsertRating(eventId, userId, rating, comment);
    }

    public EventDtos.EventRatingStatsDto getEventRatingStats(String eventId, String viewerUserId) {
        repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        return ratingRepo.findStats(eventId, viewerUserId);
    }

    public EventDtos.UserRatingDto getUserRating(String userId) {
        EventDtos.UserRatingDto dto = ratingRepo.findUserRating(userId);
        if (dto == null) throw new NotFoundException("User has fewer than 3 approved events");
        return dto;
    }

    public List<EventDtos.RatingReviewDto> getEventReviews(String eventId, String requesterUserId) {
        var row = repo.findEventRowById(eventId).orElseThrow(() -> new NotFoundException("Event not found"));
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new ForbiddenException("Unauthorized");
        }
        if (!requesterUserId.equals(row.createdById())) {
            throw new ForbiddenException("Only creator can view reviews");
        }
        return ratingRepo.findReviews(eventId);
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private EventDtos.EventDto toDto(EventRepository.EventRow row, String viewerUserId, NearbyMeta nearby) {
        EventDtos.CreatorDto createdBy = nearby != null ? nearby.createdBy() : repo.findCreatorByEventId(row.id()).orElse(null);

        long participantCount = nearby != null ? nearby.participantCount() : repo.countParticipants(row.id());
        List<EventDtos.ParticipantDto> participants = repo.findTopParticipants(row.id(), 5);

        EventDtos.CountDto count = nearby != null ? null : new EventDtos.CountDto(participantCount);

        boolean isParticipating = false;
        String userParticipationStatus = null;
        if (viewerUserId != null && !viewerUserId.isBlank()) {
            isParticipating = repo.isParticipating(row.id(), viewerUserId);
            userParticipationStatus = repo.getParticipationStatus(row.id(), viewerUserId);
        }

        Double distance = nearby != null ? nearby.distance() : null;

        String primaryImage = row.imageUrl();
        List<String> normalizedImages = new ArrayList<>();
        if (row.imageUrls() != null) {
            normalizedImages.addAll(row.imageUrls());
        }
        if ((primaryImage == null || primaryImage.isBlank()) && !normalizedImages.isEmpty()) {
            primaryImage = normalizedImages.get(0);
        }
        if (primaryImage != null && !primaryImage.isBlank()) {
            normalizedImages.add(0, primaryImage);
        }
        normalizedImages = new ArrayList<>(new LinkedHashSet<>(normalizedImages));

        EventDtos.EventRatingStatsDto ratingStats = ratingRepo.findStats(row.id(), viewerUserId);

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
                primaryImage,
                normalizedImages,
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
                userParticipationStatus,
                distance,
                ratingStats
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
