package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/AnathanWang/andexevents/services/users-service/internal/model"
	"github.com/AnathanWang/andexevents/services/users-service/internal/service"
)

// UserHandler обработчик HTTP запросов для пользователей
type UserHandler struct {
	userService service.UserService
}

// NewUserHandler создаёт новый обработчик пользователей
func NewUserHandler(userService service.UserService) *UserHandler {
	return &UserHandler{
		userService: userService,
	}
}

// CreateUser создаёт нового пользователя
// POST /api/users
func (h *UserHandler) CreateUser(c *gin.Context) {
	// Получаем данные из middleware auth (supabaseUID и email из токена)
	supabaseUID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: valid token with uid is required",
		})
		return
	}

	email, exists := c.Get("email")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: valid token with email is required",
		})
		return
	}

	// Парсим дополнительные поля из body
	var req model.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Это нормально, если тело пустое - поля опциональны
	}

	user, err := h.userService.CreateUser(
		c.Request.Context(),
		supabaseUID.(string),
		email.(string),
		req.DisplayName,
		req.PhotoURL,
	)

	if err != nil {
		if errors.Is(err, service.ErrUserAlreadyExists) {
			c.JSON(http.StatusConflict, model.ErrorResponse{
				Success: false,
				Message: err.Error(),
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to create user",
		})
		return
	}

	c.JSON(http.StatusCreated, model.UserResponse{
		Success: true,
		Data:    user,
	})
}

// GetCurrentUser получает профиль текущего пользователя
// GET /api/users/me
func (h *UserHandler) GetCurrentUser(c *gin.Context) {
	// Получаем userID из БД (установлен в middleware)
	userID, exists := c.Get("dbUserID")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	user, err := h.userService.GetCurrentUser(c.Request.Context(), userID.(string))
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, model.ErrorResponse{
				Success: false,
				Message: "User not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to get user",
		})
		return
	}

	c.JSON(http.StatusOK, model.UserResponse{
		Success: true,
		Data:    user,
	})
}

// UpdateProfile обновляет профиль пользователя
// PUT /api/users/me
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID, exists := c.Get("dbUserID")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	var req model.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: "Invalid request body: " + err.Error(),
		})
		return
	}

	user, err := h.userService.UpdateProfile(c.Request.Context(), userID.(string), &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, model.ErrorResponse{
				Success: false,
				Message: "User not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to update profile",
		})
		return
	}

	c.JSON(http.StatusOK, model.UserResponse{
		Success: true,
		Data:    user,
	})
}

// UpdateLocation обновляет геолокацию пользователя
// PUT /api/users/me/location
func (h *UserHandler) UpdateLocation(c *gin.Context) {
	userID, exists := c.Get("dbUserID")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	var req model.UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180",
		})
		return
	}

	err := h.userService.UpdateLocation(c.Request.Context(), userID.(string), req.Latitude, req.Longitude)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCoordinates) {
			c.JSON(http.StatusBadRequest, model.ErrorResponse{
				Success: false,
				Message: "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180",
			})
			return
		}
		if errors.Is(err, service.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, model.ErrorResponse{
				Success: false,
				Message: "User not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to update location",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Location updated successfully",
	})
}

// GetMatches получает список потенциальных матчей
// GET /api/users/matches
func (h *UserHandler) GetMatches(c *gin.Context) {
	userID, exists := c.Get("dbUserID")
	if !exists {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	var req model.GetMatchesRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: "Invalid query parameters: " + err.Error(),
		})
		return
	}

	// Устанавливаем значения по умолчанию
	if req.RadiusKm == 0 {
		req.RadiusKm = 50
	}
	if req.Limit == 0 {
		req.Limit = 20
	}

	// Валидация координат если они предоставлены
	if req.Latitude != nil && req.Longitude != nil {
		if *req.Latitude < -90 || *req.Latitude > 90 || *req.Longitude < -180 || *req.Longitude > 180 {
			c.JSON(http.StatusBadRequest, model.ErrorResponse{
				Success: false,
				Message: "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180",
			})
			return
		}
	}

	matches, err := h.userService.GetMatches(
		c.Request.Context(),
		userID.(string),
		req.Latitude,
		req.Longitude,
		req.RadiusKm,
		req.Limit,
	)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, model.ErrorResponse{
				Success: false,
				Message: "User not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to fetch matches",
		})
		return
	}

	c.JSON(http.StatusOK, model.UsersResponse{
		Success: true,
		Data:    matches,
	})
}
