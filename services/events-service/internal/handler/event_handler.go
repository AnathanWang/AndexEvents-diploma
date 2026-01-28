package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
	"github.com/AnathanWang/andexevents/services/events-service/internal/service"
)

type EventHandler struct {
	eventService service.EventService
}

// NewEventHandler создаёт новый обработчик событий
func NewEventHandler(eventService service.EventService) *EventHandler {
	return &EventHandler{eventService: eventService}
}

// CreateEvent создаёт новое событие
// @Summary Create event
// @Tags events
// @Accept json
// @Produce json
// @Param event body model.CreateEventRequest true "Event data"
// @Success 201 {object} model.Event
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Router /api/events [post]
func (h *EventHandler) CreateEvent(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "unauthorized"})
		return
	}

	var req model.CreateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	event, err := h.eventService.CreateEvent(c.Request.Context(), userID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, event)
}

// GetEvents получает список событий
// @Summary Get events
// @Tags events
// @Produce json
// @Param page query int false "Page number"
// @Param pageSize query int false "Page size"
// @Param category query string false "Category filter"
// @Param search query string false "Search query"
// @Param lat query number false "Latitude for nearby search"
// @Param lon query number false "Longitude for nearby search"
// @Param radius query number false "Radius in meters"
// @Success 200 {object} model.PaginatedEventsResponse
// @Router /api/events [get]
func (h *EventHandler) GetEvents(c *gin.Context) {
	lat, _ := strconv.ParseFloat(c.Query("lat"), 64)
	lon, _ := strconv.ParseFloat(c.Query("lon"), 64)
	radius, _ := strconv.ParseFloat(c.Query("radius"), 64)
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	if lat != 0 && lon != 0 {
		events, err := h.eventService.GetNearbyEvents(c.Request.Context(), lat, lon, radius, page, pageSize)
		if err != nil {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusOK, events)
		return
	}

	var isOnline *bool
	if onlineStr := c.Query("isOnline"); onlineStr != "" {
		online := onlineStr == "true"
		isOnline = &online
	}

	var status *model.EventStatus
	if statusStr := c.Query("status"); statusStr != "" {
		s := model.EventStatus(statusStr)
		status = &s
	}

	req := &model.GetEventsRequest{
		Page:      page,
		PageSize:  pageSize,
		Category:  c.Query("category"),
		Search:    c.Query("search"),
		SortBy:    c.DefaultQuery("sortBy", "dateTime"),
		SortOrder: c.DefaultQuery("sortOrder", "asc"),
		IsOnline:  isOnline,
		Status:    status,
	}

	events, err := h.eventService.GetEvents(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, events)
}

// GetEventByID получает событие по ID
// @Summary Get event by ID
// @Tags events
// @Produce json
// @Param id path string true "Event ID"
// @Success 200 {object} model.EventResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id} [get]
func (h *EventHandler) GetEventByID(c *gin.Context) {
	id := c.Param("id")

	event, err := h.eventService.GetEventByID(c.Request.Context(), id)
	if err != nil {
		if err == service.ErrEventNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, event)
}

// GetUserEvents получает события пользователя
// @Summary Get user events
// @Tags events
// @Produce json
// @Param userId path string true "User ID"
// @Param page query int false "Page number"
// @Param pageSize query int false "Page size"
// @Success 200 {object} model.PaginatedEventsResponse
// @Router /api/events/user/{userId} [get]
func (h *EventHandler) GetUserEvents(c *gin.Context) {
	userID := c.Param("userId")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	events, err := h.eventService.GetUserEvents(c.Request.Context(), userID, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, events)
}

// UpdateEvent обновляет событие
// @Summary Update event
// @Tags events
// @Accept json
// @Produce json
// @Param id path string true "Event ID"
// @Param event body model.UpdateEventRequest true "Update data"
// @Success 200 {object} model.Event
// @Failure 400 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id} [put]
func (h *EventHandler) UpdateEvent(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "unauthorized"})
		return
	}

	id := c.Param("id")

	var req model.UpdateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	event, err := h.eventService.UpdateEvent(c.Request.Context(), userID, id, &req)
	if err != nil {
		switch err {
		case service.ErrEventNotFound:
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
		case service.ErrNotEventOwner:
			c.JSON(http.StatusForbidden, ErrorResponse{Error: "not event owner"})
		default:
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, event)
}

// DeleteEvent удаляет событие
// @Summary Delete event
// @Tags events
// @Param id path string true "Event ID"
// @Success 204
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id} [delete]
func (h *EventHandler) DeleteEvent(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "unauthorized"})
		return
	}

	id := c.Param("id")

	err := h.eventService.DeleteEvent(c.Request.Context(), userID, id)
	if err != nil {
		switch err {
		case service.ErrEventNotFound:
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
		case service.ErrNotEventOwner:
			c.JSON(http.StatusForbidden, ErrorResponse{Error: "not event owner"})
		default:
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		}
		return
	}

	c.Status(http.StatusNoContent)
}

// JoinEvent присоединяет пользователя к событию
// @Summary Join event
// @Tags events
// @Param id path string true "Event ID"
// @Success 200
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id}/participate [post]
func (h *EventHandler) JoinEvent(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "unauthorized"})
		return
	}

	eventID := c.Param("id")

	err := h.eventService.JoinEvent(c.Request.Context(), userID, eventID)
	if err != nil {
		switch err {
		case service.ErrEventNotFound:
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
		case service.ErrAlreadyParticipant:
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "already a participant"})
		case service.ErrEventFull:
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "event is full"})
		default:
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "successfully joined event"})
}

// LeaveEvent удаляет пользователя из участников события
// @Summary Leave event
// @Tags events
// @Param id path string true "Event ID"
// @Success 200
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id}/participate [delete]
func (h *EventHandler) LeaveEvent(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "unauthorized"})
		return
	}

	eventID := c.Param("id")

	err := h.eventService.LeaveEvent(c.Request.Context(), userID, eventID)
	if err != nil {
		switch err {
		case service.ErrEventNotFound:
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
		case service.ErrNotParticipant:
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "not a participant"})
		default:
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "successfully left event"})
}

// GetParticipants получает список участников события
// @Summary Get event participants
// @Tags events
// @Produce json
// @Param id path string true "Event ID"
// @Param page query int false "Page number"
// @Param pageSize query int false "Page size"
// @Success 200 {object} model.ParticipantsResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/events/{id}/participants [get]
func (h *EventHandler) GetParticipants(c *gin.Context) {
	eventID := c.Param("id")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	participants, err := h.eventService.GetParticipants(c.Request.Context(), eventID, page, pageSize)
	if err != nil {
		if err == service.ErrEventNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, participants)
}

// ErrorResponse структура ответа с ошибкой
type ErrorResponse struct {
	Error string `json:"error"`
}
