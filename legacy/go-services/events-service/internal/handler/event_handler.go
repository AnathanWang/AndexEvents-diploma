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
// @Param limit query int false "Page size (alias for Node.js compatibility)"
// @Param category query string false "Category filter"
// @Param search query string false "Search query"
// @Param latitude query number false "Latitude for nearby search"
// @Param longitude query number false "Longitude for nearby search"
// @Param maxDistance query number false "Max distance in meters"
// @Success 200 {object} model.PaginatedEventsWithDetailsResponse
// @Router /api/events [get]
func (h *EventHandler) GetEvents(c *gin.Context) {
	// Support both lat/lon and latitude/longitude (Node.js compatibility)
	lat, _ := strconv.ParseFloat(c.Query("latitude"), 64)
	if lat == 0 {
		lat, _ = strconv.ParseFloat(c.Query("lat"), 64)
	}
	lon, _ := strconv.ParseFloat(c.Query("longitude"), 64)
	if lon == 0 {
		lon, _ = strconv.ParseFloat(c.Query("lon"), 64)
	}

	// Support both maxDistance and radius
	maxDistance, _ := strconv.ParseFloat(c.Query("maxDistance"), 64)
	if maxDistance == 0 {
		maxDistance, _ = strconv.ParseFloat(c.Query("radius"), 64)
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	
	// Support both pageSize and limit (Node.js compatibility)
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	if limit, err := strconv.Atoi(c.Query("limit")); err == nil && limit > 0 {
		pageSize = limit
	}

	// Get userID from context (optional auth)
	userID := c.GetString("userID")

	if lat != 0 && lon != 0 {
		events, err := h.eventService.GetNearbyEvents(c.Request.Context(), lat, lon, maxDistance, page, pageSize, userID)
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
		UserID:    userID,
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
	userID := c.GetString("userID") // optional auth

	event, err := h.eventService.GetEventByID(c.Request.Context(), id, userID)
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
// @Accept json
// @Param id path string true "Event ID"
// @Param status body model.ParticipateRequest true "Participation status"
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

	// Parse participation status from body
	var req model.ParticipateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Default to GOING if no body provided (backward compatibility)
		req.Status = model.ParticipantStatusGoing
	}

	// Validate status
	if req.Status != model.ParticipantStatusGoing && req.Status != model.ParticipantStatusInterested {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid status, must be GOING or INTERESTED"})
		return
	}

	err := h.eventService.JoinEvent(c.Request.Context(), userID, eventID, req.Status)
	if err != nil {
		switch err {
		case service.ErrEventNotFound:
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "event not found"})
		case service.ErrEventNotApproved:
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "cannot participate in unapproved event"})
		case service.ErrEventFull:
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "event is full"})
		default:
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Participation status updated",
		"data": gin.H{
			"eventId": eventID,
			"userId":  userID,
			"status":  req.Status,
		},
	})
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
