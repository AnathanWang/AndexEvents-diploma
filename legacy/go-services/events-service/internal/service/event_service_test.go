package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
)

// MockEventRepository мок для EventRepository
type MockEventRepository struct {
	mock.Mock
}

func (m *MockEventRepository) Create(ctx context.Context, event *model.Event) error {
	args := m.Called(ctx, event)
	return args.Error(0)
}

func (m *MockEventRepository) GetByID(ctx context.Context, id string) (*model.Event, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Event), args.Error(1)
}

func (m *MockEventRepository) GetAll(ctx context.Context, req *model.GetEventsRequest) ([]model.Event, int, error) {
	args := m.Called(ctx, req)
	return args.Get(0).([]model.Event), args.Int(1), args.Error(2)
}

func (m *MockEventRepository) GetByUserID(ctx context.Context, userID string, page, pageSize int) ([]model.Event, int, error) {
	args := m.Called(ctx, userID, page, pageSize)
	return args.Get(0).([]model.Event), args.Int(1), args.Error(2)
}

func (m *MockEventRepository) Update(ctx context.Context, id string, req *model.UpdateEventRequest) (*model.Event, error) {
	args := m.Called(ctx, id, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Event), args.Error(1)
}

func (m *MockEventRepository) Delete(ctx context.Context, id string) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockEventRepository) GetNearby(ctx context.Context, lat, lon, radius float64, page, pageSize int) ([]model.Event, int, error) {
	args := m.Called(ctx, lat, lon, radius, page, pageSize)
	return args.Get(0).([]model.Event), args.Int(1), args.Error(2)
}

func (m *MockEventRepository) GetCreatorByEventID(ctx context.Context, eventID string) (*model.EventCreator, error) {
	args := m.Called(ctx, eventID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.EventCreator), args.Error(1)
}

// MockParticipantRepository мок для ParticipantRepository
type MockParticipantRepository struct {
	mock.Mock
}

func (m *MockParticipantRepository) AddParticipant(ctx context.Context, participant *model.Participant) error {
	args := m.Called(ctx, participant)
	return args.Error(0)
}

func (m *MockParticipantRepository) RemoveParticipant(ctx context.Context, eventID, userID string) error {
	args := m.Called(ctx, eventID, userID)
	return args.Error(0)
}

func (m *MockParticipantRepository) GetParticipants(ctx context.Context, eventID string, page, pageSize int) ([]model.ParticipantWithUser, int, error) {
	args := m.Called(ctx, eventID, page, pageSize)
	return args.Get(0).([]model.ParticipantWithUser), args.Int(1), args.Error(2)
}

func (m *MockParticipantRepository) GetParticipation(ctx context.Context, eventID, userID string) (*model.Participant, error) {
	args := m.Called(ctx, eventID, userID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Participant), args.Error(1)
}

func (m *MockParticipantRepository) GetParticipantCount(ctx context.Context, eventID string) (int, error) {
	args := m.Called(ctx, eventID)
	return args.Int(0), args.Error(1)
}

func (m *MockParticipantRepository) UpdateStatus(ctx context.Context, eventID, userID string, status model.ParticipantStatus) error {
	args := m.Called(ctx, eventID, userID, status)
	return args.Error(0)
}

func TestCreateEvent(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	dateTime := time.Now().Add(24 * time.Hour)
	desc := "Test Description"
	loc := "Test Location"
	req := &model.CreateEventRequest{
		Title:       "Test Event",
		Description: &desc,
		Category:    "music",
		Location:    &loc,
		DateTime:    dateTime,
	}

	eventRepo.On("Create", ctx, mock.AnythingOfType("*model.Event")).Return(nil)

	event, err := svc.CreateEvent(ctx, "user-123", req)

	assert.NoError(t, err)
	assert.NotNil(t, event)
	assert.Equal(t, "Test Event", event.Title)
	assert.Equal(t, "user-123", event.CreatedByID)
	assert.NotEmpty(t, event.ID)
	eventRepo.AssertExpectations(t)
}

func TestCreateEvent_RepositoryError(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	req := &model.CreateEventRequest{
		Title:    "Test Event",
		DateTime: time.Now().Add(24 * time.Hour),
	}

	eventRepo.On("Create", ctx, mock.AnythingOfType("*model.Event")).Return(errors.New("db error"))

	event, err := svc.CreateEvent(ctx, "user-123", req)

	assert.Error(t, err)
	assert.Nil(t, event)
	eventRepo.AssertExpectations(t)
}

func TestGetEventByID(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	expectedEvent := &model.Event{
		ID:          "event-123",
		Title:       "Test Event",
		CreatedByID: "user-123",
	}

	expectedCreator := &model.EventCreator{
		ID:        "user-123",
		DisplayName: "Test User",
	}

	participants := []model.ParticipantWithUser{
		{EventID: "event-123", UserID: "user-1", Name: "Participant 1"},
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(expectedEvent, nil)
	participantRepo.On("GetParticipantCount", ctx, "event-123").Return(5, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-123").Return(expectedCreator, nil)
	participantRepo.On("GetParticipants", ctx, "event-123", 1, 5).Return(participants, 1, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(&model.Participant{EventID: "event-123", UserID: "user-123", Status: model.ParticipantStatusGoing}, nil)

	response, err := svc.GetEventByID(ctx, "event-123", "user-123")

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Equal(t, "event-123", response.Event.ID)
	assert.Equal(t, 5, response.Count.Participants)
	assert.Equal(t, "Test User", response.CreatedBy.DisplayName)
	assert.True(t, response.IsParticipating)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestGetEventByID_NoUser(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	expectedEvent := &model.Event{
		ID:          "event-123",
		Title:       "Test Event",
		CreatedByID: "user-123",
	}

	expectedCreator := &model.EventCreator{
		ID:        "user-123",
		DisplayName: "Test User",
	}

	participants := []model.ParticipantWithUser{
		{EventID: "event-123", UserID: "user-1", Name: "Participant 1"},
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(expectedEvent, nil)
	participantRepo.On("GetParticipantCount", ctx, "event-123").Return(5, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-123").Return(expectedCreator, nil)
	participantRepo.On("GetParticipants", ctx, "event-123", 1, 5).Return(participants, 1, nil)

	response, err := svc.GetEventByID(ctx, "event-123", "")

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Equal(t, "event-123", response.Event.ID)
	assert.False(t, response.IsParticipating)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestGetEventByID_NotFound(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	eventRepo.On("GetByID", ctx, "nonexistent").Return(nil, nil)

	response, err := svc.GetEventByID(ctx, "nonexistent", "")

	assert.Error(t, err)
	assert.Equal(t, ErrEventNotFound, err)
	assert.Nil(t, response)
	eventRepo.AssertExpectations(t)
}

func TestGetEvents(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	events := []model.Event{
		{ID: "event-1", Title: "Event 1", CreatedByID: "creator-1"},
		{ID: "event-2", Title: "Event 2", CreatedByID: "creator-2"},
	}

	req := &model.GetEventsRequest{
		Page:     1,
		PageSize: 20,
		Category: "music",
	}

	creator1 := &model.EventCreator{ID: "creator-1", DisplayName: "Creator 1"}
	creator2 := &model.EventCreator{ID: "creator-2", DisplayName: "Creator 2"}
	participants := []model.ParticipantWithUser{}

	eventRepo.On("GetAll", ctx, req).Return(events, 2, nil)
	// Enrichment for event-1
	participantRepo.On("GetParticipantCount", ctx, "event-1").Return(5, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-1").Return(creator1, nil)
	participantRepo.On("GetParticipants", ctx, "event-1", 1, 5).Return(participants, 0, nil)
	// Enrichment for event-2
	participantRepo.On("GetParticipantCount", ctx, "event-2").Return(3, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-2").Return(creator2, nil)
	participantRepo.On("GetParticipants", ctx, "event-2", 1, 5).Return(participants, 0, nil)

	response, err := svc.GetEvents(ctx, req)

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Len(t, response.Events, 2)
	assert.Equal(t, 2, response.Pagination.Total)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestGetUserEvents(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	events := []model.Event{
		{ID: "event-1", Title: "Event 1", CreatedByID: "user-123"},
	}

	creator := &model.EventCreator{ID: "user-123", DisplayName: "User 123"}
	participants := []model.ParticipantWithUser{}

	eventRepo.On("GetByUserID", ctx, "user-123", 1, 20).Return(events, 1, nil)
	// Enrichment for event-1
	participantRepo.On("GetParticipantCount", ctx, "event-1").Return(3, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-1").Return(creator, nil)
	participantRepo.On("GetParticipants", ctx, "event-1", 1, 5).Return(participants, 0, nil)

	response, err := svc.GetUserEvents(ctx, "user-123", 1, 20)

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Len(t, response.Events, 1)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestUpdateEvent(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	existingEvent := &model.Event{
		ID:          "event-123",
		Title:       "Old Title",
		CreatedByID: "user-123",
	}

	newTitle := "New Title"
	req := &model.UpdateEventRequest{
		Title: &newTitle,
	}

	updatedEvent := &model.Event{
		ID:          "event-123",
		Title:       "New Title",
		CreatedByID: "user-123",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(existingEvent, nil)
	eventRepo.On("Update", ctx, "event-123", req).Return(updatedEvent, nil)

	event, err := svc.UpdateEvent(ctx, "user-123", "event-123", req)

	assert.NoError(t, err)
	assert.NotNil(t, event)
	assert.Equal(t, "New Title", event.Title)
	eventRepo.AssertExpectations(t)
}

func TestUpdateEvent_NotOwner(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	existingEvent := &model.Event{
		ID:          "event-123",
		Title:       "Old Title",
		CreatedByID: "user-123",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(existingEvent, nil)

	newTitle := "New Title"
	req := &model.UpdateEventRequest{
		Title: &newTitle,
	}

	event, err := svc.UpdateEvent(ctx, "another-user", "event-123", req)

	assert.Error(t, err)
	assert.Equal(t, ErrNotEventOwner, err)
	assert.Nil(t, event)
	eventRepo.AssertExpectations(t)
}

func TestDeleteEvent(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	existingEvent := &model.Event{
		ID:          "event-123",
		CreatedByID: "user-123",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(existingEvent, nil)
	eventRepo.On("Delete", ctx, "event-123").Return(nil)

	err := svc.DeleteEvent(ctx, "user-123", "event-123")

	assert.NoError(t, err)
	eventRepo.AssertExpectations(t)
}

func TestDeleteEvent_NotOwner(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	existingEvent := &model.Event{
		ID:          "event-123",
		CreatedByID: "user-123",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(existingEvent, nil)

	err := svc.DeleteEvent(ctx, "another-user", "event-123")

	assert.Error(t, err)
	assert.Equal(t, ErrNotEventOwner, err)
	eventRepo.AssertExpectations(t)
}

func TestJoinEvent(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	event := &model.Event{
		ID:     "event-123",
		Title:  "Test Event",
		Status: model.EventStatusApproved,
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(nil, nil)
	participantRepo.On("AddParticipant", ctx, mock.AnythingOfType("*model.Participant")).Return(nil)

	err := svc.JoinEvent(ctx, "user-123", "event-123", model.ParticipantStatusGoing)

	assert.NoError(t, err)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestJoinEvent_UpdateStatus(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	event := &model.Event{
		ID:     "event-123",
		Title:  "Test Event",
		Status: model.EventStatusApproved,
	}

	existingParticipant := &model.Participant{
		EventID: "event-123",
		UserID:  "user-123",
		Status:  model.ParticipantStatusInterested,
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(existingParticipant, nil)
	// Upsert uses AddParticipant with ON CONFLICT DO UPDATE
	participantRepo.On("AddParticipant", ctx, mock.AnythingOfType("*model.Participant")).Return(nil)

	err := svc.JoinEvent(ctx, "user-123", "event-123", model.ParticipantStatusGoing)

	assert.NoError(t, err)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestJoinEvent_EventFull(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	maxParticipants := 10
	event := &model.Event{
		ID:              "event-123",
		Title:           "Test Event",
		Status:          model.EventStatusApproved,
		MaxParticipants: &maxParticipants,
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(nil, nil)
	participantRepo.On("GetParticipantCount", ctx, "event-123").Return(10, nil)

	err := svc.JoinEvent(ctx, "user-123", "event-123", model.ParticipantStatusGoing)

	assert.Error(t, err)
	assert.Equal(t, ErrEventFull, err)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestLeaveEvent(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	event := &model.Event{
		ID:    "event-123",
		Title: "Test Event",
	}

	existingParticipant := &model.Participant{
		EventID: "event-123",
		UserID:  "user-123",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(existingParticipant, nil)
	participantRepo.On("RemoveParticipant", ctx, "event-123", "user-123").Return(nil)

	err := svc.LeaveEvent(ctx, "user-123", "event-123")

	assert.NoError(t, err)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestLeaveEvent_NotParticipant(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	event := &model.Event{
		ID:    "event-123",
		Title: "Test Event",
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipation", ctx, "event-123", "user-123").Return(nil, nil)

	err := svc.LeaveEvent(ctx, "user-123", "event-123")

	assert.Error(t, err)
	assert.Equal(t, ErrNotParticipant, err)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestGetParticipants(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	event := &model.Event{
		ID:    "event-123",
		Title: "Test Event",
	}

	participants := []model.ParticipantWithUser{
		{
			EventID: "event-123",
			UserID:  "user-1",
			Name:    "User 1",
		},
		{
			EventID: "event-123",
			UserID:  "user-2",
			Name:    "User 2",
		},
	}

	eventRepo.On("GetByID", ctx, "event-123").Return(event, nil)
	participantRepo.On("GetParticipants", ctx, "event-123", 1, 20).Return(participants, 2, nil)

	response, err := svc.GetParticipants(ctx, "event-123", 1, 20)

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Len(t, response.Participants, 2)
	assert.Equal(t, 2, response.Total)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}

func TestGetNearbyEvents(t *testing.T) {
	ctx := context.Background()
	eventRepo := new(MockEventRepository)
	participantRepo := new(MockParticipantRepository)
	svc := NewEventService(eventRepo, participantRepo)

	distance := 1500.0
	events := []model.Event{
		{ID: "event-1", Title: "Nearby Event", Distance: &distance, CreatedByID: "creator-1"},
	}

	creator := &model.EventCreator{ID: "creator-1", DisplayName: "Creator"}
	participants := []model.ParticipantWithUser{}

	eventRepo.On("GetNearby", ctx, 55.75, 37.61, 10000.0, 1, 20).Return(events, 1, nil)
	participantRepo.On("GetParticipantCount", ctx, "event-1").Return(5, nil)
	eventRepo.On("GetCreatorByEventID", ctx, "event-1").Return(creator, nil)
	participantRepo.On("GetParticipants", ctx, "event-1", 1, 5).Return(participants, 0, nil)

	response, err := svc.GetNearbyEvents(ctx, 55.75, 37.61, 10000.0, 1, 20, "")

	assert.NoError(t, err)
	assert.NotNil(t, response)
	assert.Len(t, response.Events, 1)
	assert.Equal(t, 1500.0, *response.Events[0].Distance)
	eventRepo.AssertExpectations(t)
	participantRepo.AssertExpectations(t)
}
