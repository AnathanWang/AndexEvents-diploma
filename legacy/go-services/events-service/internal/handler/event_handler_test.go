package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
	"github.com/AnathanWang/andexevents/services/events-service/internal/service"
)

// MockEventService мок для EventService
type MockEventService struct {
	mock.Mock
}

func (m *MockEventService) CreateEvent(ctx context.Context, userID string, req *model.CreateEventRequest) (*model.Event, error) {
	args := m.Called(ctx, userID, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Event), args.Error(1)
}

func (m *MockEventService) GetEventByID(ctx context.Context, id string, userID string) (*model.EventResponse, error) {
	args := m.Called(ctx, id, userID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.EventResponse), args.Error(1)
}

func (m *MockEventService) GetEvents(ctx context.Context, req *model.GetEventsRequest) (*model.PaginatedEventsWithDetailsResponse, error) {
	args := m.Called(ctx, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.PaginatedEventsWithDetailsResponse), args.Error(1)
}

func (m *MockEventService) GetUserEvents(ctx context.Context, userID string, page, pageSize int) (*model.PaginatedEventsWithDetailsResponse, error) {
	args := m.Called(ctx, userID, page, pageSize)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.PaginatedEventsWithDetailsResponse), args.Error(1)
}

func (m *MockEventService) GetNearbyEvents(ctx context.Context, lat, lon, radius float64, page, pageSize int, userID string) (*model.PaginatedEventsWithDetailsResponse, error) {
	args := m.Called(ctx, lat, lon, radius, page, pageSize, userID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.PaginatedEventsWithDetailsResponse), args.Error(1)
}

func (m *MockEventService) UpdateEvent(ctx context.Context, userID, eventID string, req *model.UpdateEventRequest) (*model.Event, error) {
	args := m.Called(ctx, userID, eventID, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Event), args.Error(1)
}

func (m *MockEventService) DeleteEvent(ctx context.Context, userID, eventID string) error {
	args := m.Called(ctx, userID, eventID)
	return args.Error(0)
}

func (m *MockEventService) JoinEvent(ctx context.Context, userID, eventID string, status model.ParticipantStatus) error {
	args := m.Called(ctx, userID, eventID, status)
	return args.Error(0)
}

func (m *MockEventService) LeaveEvent(ctx context.Context, userID, eventID string) error {
	args := m.Called(ctx, userID, eventID)
	return args.Error(0)
}

func (m *MockEventService) GetParticipants(ctx context.Context, eventID string, page, pageSize int) (*model.ParticipantsResponse, error) {
	args := m.Called(ctx, eventID, page, pageSize)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.ParticipantsResponse), args.Error(1)
}

func setupRouter(mockService *MockEventService) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	handler := NewEventHandler(mockService)

	api := router.Group("/api/events")
	{
		api.GET("", handler.GetEvents)
		api.GET("/:id", handler.GetEventByID)
		api.GET("/user/:userId", handler.GetUserEvents)
		api.GET("/:id/participants", handler.GetParticipants)
		api.POST("", setUserID("user-123"), handler.CreateEvent)
		api.PUT("/:id", setUserID("user-123"), handler.UpdateEvent)
		api.DELETE("/:id", setUserID("user-123"), handler.DeleteEvent)
		api.POST("/:id/participate", setUserID("user-123"), handler.JoinEvent)
		api.DELETE("/:id/participate", setUserID("user-123"), handler.LeaveEvent)
	}

	return router
}

func setUserID(userID string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("userID", userID)
		c.Next()
	}
}

func TestCreateEvent_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	desc := "Test Description"
	reqBody := model.CreateEventRequest{
		Title:       "Test Event",
		Description: &desc,
		Category:    "music",
		DateTime:    time.Now().Add(24 * time.Hour),
	}

	expectedDesc := "Test Description"
	expectedEvent := &model.Event{
		ID:          "event-123",
		Title:       "Test Event",
		Description: &expectedDesc,
		Category:    "music",
		CreatedByID: "user-123",
	}

	mockService.On("CreateEvent", mock.Anything, "user-123", mock.AnythingOfType("*model.CreateEventRequest")).Return(expectedEvent, nil)

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("POST", "/api/events", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusCreated, w.Code)

	var response model.Event
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Equal(t, "event-123", response.ID)
	assert.Equal(t, "Test Event", response.Title)
	mockService.AssertExpectations(t)
}

func TestCreateEvent_Handler_Unauthorized(t *testing.T) {
	mockService := new(MockEventService)
	gin.SetMode(gin.TestMode)
	router := gin.New()

	handler := NewEventHandler(mockService)
	router.POST("/api/events", handler.CreateEvent)

	reqBody := model.CreateEventRequest{
		Title:    "Test Event",
		DateTime: time.Now().Add(24 * time.Hour),
	}

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("POST", "/api/events", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestGetEvents_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	expectedResponse := &model.PaginatedEventsWithDetailsResponse{
		Events: []model.EventWithDetails{
			{Event: model.Event{ID: "event-1", Title: "Event 1"}},
			{Event: model.Event{ID: "event-2", Title: "Event 2"}},
		},
		Pagination: model.PaginationInfo{
			Total:   2,
			Page:    1,
			Limit: 20,
			TotalPages:   1,
		},
	}

	mockService.On("GetEvents", mock.Anything, mock.AnythingOfType("*model.GetEventsRequest")).Return(expectedResponse, nil)

	req, _ := http.NewRequest("GET", "/api/events?page=1&pageSize=20", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.PaginatedEventsWithDetailsResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Len(t, response.Events, 2)
	mockService.AssertExpectations(t)
}

func TestGetEventByID_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	expectedResponse := &model.EventResponse{
		Event: model.Event{
			ID:    "event-123",
			Title: "Test Event",
		},
		Count: model.CountWrapper{Participants: 5},
	}

	mockService.On("GetEventByID", mock.Anything, "event-123", "").Return(expectedResponse, nil)

	req, _ := http.NewRequest("GET", "/api/events/event-123", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.EventResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Equal(t, "event-123", response.Event.ID)
	assert.Equal(t, 5, response.Count.Participants)
	mockService.AssertExpectations(t)
}

func TestGetEventByID_Handler_NotFound(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	mockService.On("GetEventByID", mock.Anything, "nonexistent", "").Return(nil, service.ErrEventNotFound)

	req, _ := http.NewRequest("GET", "/api/events/nonexistent", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)
	mockService.AssertExpectations(t)
}

func TestGetUserEvents_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	expectedResponse := &model.PaginatedEventsWithDetailsResponse{
		Events: []model.EventWithDetails{
			{Event: model.Event{ID: "event-1", Title: "User Event", CreatedByID: "user-456"}},
		},
		Pagination: model.PaginationInfo{
			Total:   1,
			Page:    1,
			Limit: 20,
			TotalPages:   1,
		},
	}

	mockService.On("GetUserEvents", mock.Anything, "user-456", 1, 20).Return(expectedResponse, nil)

	req, _ := http.NewRequest("GET", "/api/events/user/user-456?page=1&pageSize=20", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.PaginatedEventsWithDetailsResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Len(t, response.Events, 1)
	mockService.AssertExpectations(t)
}

func TestUpdateEvent_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	newTitle := "Updated Title"
	reqBody := model.UpdateEventRequest{
		Title: &newTitle,
	}

	expectedEvent := &model.Event{
		ID:          "event-123",
		Title:       "Updated Title",
		CreatedByID: "user-123",
	}

	mockService.On("UpdateEvent", mock.Anything, "user-123", "event-123", mock.AnythingOfType("*model.UpdateEventRequest")).Return(expectedEvent, nil)

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("PUT", "/api/events/event-123", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.Event
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Equal(t, "Updated Title", response.Title)
	mockService.AssertExpectations(t)
}

func TestUpdateEvent_Handler_NotOwner(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	newTitle := "Updated Title"
	reqBody := model.UpdateEventRequest{
		Title: &newTitle,
	}

	mockService.On("UpdateEvent", mock.Anything, "user-123", "event-123", mock.AnythingOfType("*model.UpdateEventRequest")).Return(nil, service.ErrNotEventOwner)

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("PUT", "/api/events/event-123", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusForbidden, w.Code)
	mockService.AssertExpectations(t)
}

func TestDeleteEvent_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	mockService.On("DeleteEvent", mock.Anything, "user-123", "event-123").Return(nil)

	req, _ := http.NewRequest("DELETE", "/api/events/event-123", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNoContent, w.Code)
	mockService.AssertExpectations(t)
}

func TestJoinEvent_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	mockService.On("JoinEvent", mock.Anything, "user-123", "event-123", model.ParticipantStatusGoing).Return(nil)

	reqBody := `{"status": "GOING"}`
	req, _ := http.NewRequest("POST", "/api/events/event-123/participate", bytes.NewBufferString(reqBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

func TestJoinEvent_Handler_EventFull(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	mockService.On("JoinEvent", mock.Anything, "user-123", "event-123", model.ParticipantStatusGoing).Return(service.ErrEventFull)

	reqBody := `{"status": "GOING"}`
	req, _ := http.NewRequest("POST", "/api/events/event-123/participate", bytes.NewBufferString(reqBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
	mockService.AssertExpectations(t)
}

func TestLeaveEvent_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	mockService.On("LeaveEvent", mock.Anything, "user-123", "event-123").Return(nil)

	req, _ := http.NewRequest("DELETE", "/api/events/event-123/participate", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

func TestGetParticipants_Handler(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	expectedResponse := &model.ParticipantsResponse{
		Participants: []model.ParticipantWithUser{
			{
				EventID: "event-123",
				UserID:  "user-1",
				Name:    "User 1",
			},
		},
		Total:      1,
		Page:       1,
		PageSize:   20,
		TotalPages: 1,
	}

	mockService.On("GetParticipants", mock.Anything, "event-123", 1, 20).Return(expectedResponse, nil)

	req, _ := http.NewRequest("GET", "/api/events/event-123/participants?page=1&pageSize=20", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.ParticipantsResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Len(t, response.Participants, 1)
	mockService.AssertExpectations(t)
}

func TestGetEvents_Handler_Nearby(t *testing.T) {
	mockService := new(MockEventService)
	router := setupRouter(mockService)

	distance := 1500.0
	expectedResponse := &model.PaginatedEventsWithDetailsResponse{
		Events: []model.EventWithDetails{
			{Event: model.Event{ID: "event-1", Title: "Nearby Event", Distance: &distance}},
		},
		Pagination: model.PaginationInfo{
			Total:   1,
			Page:    1,
			Limit: 20,
			TotalPages:   1,
		},
	}

	mockService.On("GetNearbyEvents", mock.Anything, 55.75, 37.61, 10000.0, 1, 20, "").Return(expectedResponse, nil)

	req, _ := http.NewRequest("GET", "/api/events?lat=55.75&lon=37.61&radius=10000&page=1&pageSize=20", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.PaginatedEventsWithDetailsResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Len(t, response.Events, 1)
	mockService.AssertExpectations(t)
}
