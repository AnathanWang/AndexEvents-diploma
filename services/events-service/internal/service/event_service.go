package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
	"github.com/AnathanWang/andexevents/services/events-service/internal/repository"
)

var (
	ErrEventNotFound      = errors.New("event not found")
	ErrNotEventOwner      = errors.New("not event owner")
	ErrAlreadyParticipant = errors.New("already a participant")
	ErrNotParticipant     = errors.New("not a participant")
	ErrEventFull          = errors.New("event is full")
	ErrEventNotApproved   = errors.New("cannot participate in unapproved event")
)

// EventService интерфейс сервиса событий
type EventService interface {
	CreateEvent(ctx context.Context, userID string, req *model.CreateEventRequest) (*model.Event, error)
	GetEventByID(ctx context.Context, id string, userID string) (*model.EventResponse, error)
	GetEvents(ctx context.Context, req *model.GetEventsRequest) (*model.PaginatedEventsWithDetailsResponse, error)
	GetUserEvents(ctx context.Context, userID string, page, pageSize int) (*model.PaginatedEventsWithDetailsResponse, error)
	GetNearbyEvents(ctx context.Context, lat, lon, radius float64, page, pageSize int, userID string) (*model.PaginatedEventsWithDetailsResponse, error)
	UpdateEvent(ctx context.Context, userID, eventID string, req *model.UpdateEventRequest) (*model.Event, error)
	DeleteEvent(ctx context.Context, userID, eventID string) error
	JoinEvent(ctx context.Context, userID, eventID string, status model.ParticipantStatus) error
	LeaveEvent(ctx context.Context, userID, eventID string) error
	GetParticipants(ctx context.Context, eventID string, page, pageSize int) (*model.ParticipantsResponse, error)
}

type eventService struct {
	eventRepo       repository.EventRepository
	participantRepo repository.ParticipantRepository
}

// NewEventService создаёт новый сервис событий
func NewEventService(eventRepo repository.EventRepository, participantRepo repository.ParticipantRepository) EventService {
	return &eventService{
		eventRepo:       eventRepo,
		participantRepo: participantRepo,
	}
}

// CreateEvent создаёт новое событие
func (s *eventService) CreateEvent(ctx context.Context, userID string, req *model.CreateEventRequest) (*model.Event, error) {
	event := &model.Event{
		ID:              uuid.New().String(),
		Title:           req.Title,
		Description:     req.Description,
		Category:        req.Category,
		Location:        req.Location,
		Latitude:        req.Latitude,
		Longitude:       req.Longitude,
		DateTime:        req.DateTime,
		EndDateTime:     req.EndDateTime,
		Price:           req.Price,
		ImageURL:        req.ImageURL,
		IsOnline:        req.IsOnline,
		Status:          model.EventStatusApproved,
		MaxParticipants: req.MaxParticipants,
		MinAge:          req.MinAge,
		MaxAge:          req.MaxAge,
		CreatedByID:     userID,
	}

	if err := s.eventRepo.Create(ctx, event); err != nil {
		return nil, err
	}

	return event, nil
}

// GetEventByID получает событие по ID с информацией о создателе
func (s *eventService) GetEventByID(ctx context.Context, id string, userID string) (*model.EventResponse, error) {
	event, err := s.eventRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if event == nil {
		return nil, ErrEventNotFound
	}

	participantCount, err := s.participantRepo.GetParticipantCount(ctx, id)
	if err != nil {
		return nil, err
	}

	creator, err := s.eventRepo.GetCreatorByEventID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Получаем первых 5 участников
	participants, _, err := s.participantRepo.GetParticipants(ctx, id, 1, 5)
	if err != nil {
		return nil, err
	}

	// Проверяем участие пользователя
	isParticipating := false
	if userID != "" {
		participation, err := s.participantRepo.GetParticipation(ctx, id, userID)
		if err != nil {
			return nil, err
		}
		isParticipating = participation != nil
	}

	return &model.EventResponse{
		Event:           *event,
		Count:           model.CountWrapper{Participants: participantCount},
		CreatedBy:       creator,
		IsParticipating: isParticipating,
		Participants:    participants,
	}, nil
}

// enrichEventWithDetails добавляет детали к событию
func (s *eventService) enrichEventWithDetails(ctx context.Context, event model.Event, userID string) (model.EventWithDetails, error) {
	participantCount, err := s.participantRepo.GetParticipantCount(ctx, event.ID)
	if err != nil {
		return model.EventWithDetails{}, err
	}

	creator, err := s.eventRepo.GetCreatorByEventID(ctx, event.ID)
	if err != nil {
		return model.EventWithDetails{}, err
	}

	participants, _, err := s.participantRepo.GetParticipants(ctx, event.ID, 1, 5)
	if err != nil {
		return model.EventWithDetails{}, err
	}

	isParticipating := false
	if userID != "" {
		participation, err := s.participantRepo.GetParticipation(ctx, event.ID, userID)
		if err != nil {
			return model.EventWithDetails{}, err
		}
		isParticipating = participation != nil
	}

	return model.EventWithDetails{
		Event:           event,
		CreatedBy:       creator,
		Count:           model.CountWrapper{Participants: participantCount},
		IsParticipating: isParticipating,
		Participants:    participants,
	}, nil
}

// GetEvents получает список событий с фильтрацией
func (s *eventService) GetEvents(ctx context.Context, req *model.GetEventsRequest) (*model.PaginatedEventsWithDetailsResponse, error) {
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}
	// Support Node.js 'limit' parameter
	if req.Limit > 0 {
		req.PageSize = req.Limit
	}

	events, total, err := s.eventRepo.GetAll(ctx, req)
	if err != nil {
		return nil, err
	}

	// Обогащаем события деталями
	eventsWithDetails := make([]model.EventWithDetails, 0, len(events))
	for _, event := range events {
		eventWithDetails, err := s.enrichEventWithDetails(ctx, event, req.UserID)
		if err != nil {
			return nil, err
		}
		eventsWithDetails = append(eventsWithDetails, eventWithDetails)
	}

	return &model.PaginatedEventsWithDetailsResponse{
		Events: eventsWithDetails,
		Pagination: model.PaginationInfo{
			Page:       req.Page,
			Limit:      req.PageSize,
			Total:      total,
			TotalPages: (total + req.PageSize - 1) / req.PageSize,
		},
	}, nil
}

// GetUserEvents получает события пользователя
func (s *eventService) GetUserEvents(ctx context.Context, userID string, page, pageSize int) (*model.PaginatedEventsWithDetailsResponse, error) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}

	events, total, err := s.eventRepo.GetByUserID(ctx, userID, page, pageSize)
	if err != nil {
		return nil, err
	}

	// Обогащаем события деталями
	eventsWithDetails := make([]model.EventWithDetails, 0, len(events))
	for _, event := range events {
		eventWithDetails, err := s.enrichEventWithDetails(ctx, event, "")
		if err != nil {
			return nil, err
		}
		eventsWithDetails = append(eventsWithDetails, eventWithDetails)
	}

	return &model.PaginatedEventsWithDetailsResponse{
		Events: eventsWithDetails,
		Pagination: model.PaginationInfo{
			Page:       page,
			Limit:      pageSize,
			Total:      total,
			TotalPages: (total + pageSize - 1) / pageSize,
		},
	}, nil
}

// GetNearbyEvents получает события поблизости
func (s *eventService) GetNearbyEvents(ctx context.Context, lat, lon, radius float64, page, pageSize int, userID string) (*model.PaginatedEventsWithDetailsResponse, error) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if radius <= 0 {
		radius = 50000 // 50 км по умолчанию (как в Node.js)
	}

	events, total, err := s.eventRepo.GetNearby(ctx, lat, lon, radius, page, pageSize)
	if err != nil {
		return nil, err
	}

	// Обогащаем события деталями
	eventsWithDetails := make([]model.EventWithDetails, 0, len(events))
	for _, event := range events {
		eventWithDetails, err := s.enrichEventWithDetails(ctx, event, userID)
		if err != nil {
			return nil, err
		}
		eventsWithDetails = append(eventsWithDetails, eventWithDetails)
	}

	return &model.PaginatedEventsWithDetailsResponse{
		Events: eventsWithDetails,
		Pagination: model.PaginationInfo{
			Page:       page,
			Limit:      pageSize,
			Total:      total,
			TotalPages: (total + pageSize - 1) / pageSize,
		},
	}, nil
}

// UpdateEvent обновляет событие
func (s *eventService) UpdateEvent(ctx context.Context, userID, eventID string, req *model.UpdateEventRequest) (*model.Event, error) {
	event, err := s.eventRepo.GetByID(ctx, eventID)
	if err != nil {
		return nil, err
	}
	if event == nil {
		return nil, ErrEventNotFound
	}

	if event.CreatedByID != userID {
		return nil, ErrNotEventOwner
	}

	updated, err := s.eventRepo.Update(ctx, eventID, req)
	if err != nil {
		return nil, err
	}

	return updated, nil
}

// DeleteEvent удаляет событие
func (s *eventService) DeleteEvent(ctx context.Context, userID, eventID string) error {
	event, err := s.eventRepo.GetByID(ctx, eventID)
	if err != nil {
		return err
	}
	if event == nil {
		return ErrEventNotFound
	}

	if event.CreatedByID != userID {
		return ErrNotEventOwner
	}

	return s.eventRepo.Delete(ctx, eventID)
}

// JoinEvent добавляет пользователя как участника события (upsert - обновляет статус если уже участник)
func (s *eventService) JoinEvent(ctx context.Context, userID, eventID string, status model.ParticipantStatus) error {
	event, err := s.eventRepo.GetByID(ctx, eventID)
	if err != nil {
		return err
	}
	if event == nil {
		return ErrEventNotFound
	}

	// Проверяем что событие одобрено
	if event.Status != model.EventStatusApproved {
		return ErrEventNotApproved
	}

	// Проверяем лимит участников (только для новых участников)
	existing, err := s.participantRepo.GetParticipation(ctx, eventID, userID)
	if err != nil {
		return err
	}

	if existing == nil && event.MaxParticipants != nil {
		count, err := s.participantRepo.GetParticipantCount(ctx, eventID)
		if err != nil {
			return err
		}
		if count >= *event.MaxParticipants {
			return ErrEventFull
		}
	}

	// Используем upsert - добавляем или обновляем статус
	participant := &model.Participant{
		EventID: eventID,
		UserID:  userID,
		Status:  status,
	}

	return s.participantRepo.AddParticipant(ctx, participant)
}

// LeaveEvent удаляет пользователя из участников события
func (s *eventService) LeaveEvent(ctx context.Context, userID, eventID string) error {
	event, err := s.eventRepo.GetByID(ctx, eventID)
	if err != nil {
		return err
	}
	if event == nil {
		return ErrEventNotFound
	}

	existing, err := s.participantRepo.GetParticipation(ctx, eventID, userID)
	if err != nil {
		return err
	}
	if existing == nil {
		return ErrNotParticipant
	}

	return s.participantRepo.RemoveParticipant(ctx, eventID, userID)
}

// GetParticipants получает список участников события
func (s *eventService) GetParticipants(ctx context.Context, eventID string, page, pageSize int) (*model.ParticipantsResponse, error) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}

	event, err := s.eventRepo.GetByID(ctx, eventID)
	if err != nil {
		return nil, err
	}
	if event == nil {
		return nil, ErrEventNotFound
	}

	participants, total, err := s.participantRepo.GetParticipants(ctx, eventID, page, pageSize)
	if err != nil {
		return nil, err
	}

	return &model.ParticipantsResponse{
		Participants: participants,
		Total:        total,
		Page:         page,
		PageSize:     pageSize,
		TotalPages:   (total + pageSize - 1) / pageSize,
	}, nil
}
