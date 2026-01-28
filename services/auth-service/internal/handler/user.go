package handler

import (
	"context"
	"errors"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/model"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/service"
	"github.com/AnathanWang/andexevents/shared/pkg/response"
	"github.com/AnathanWang/andexevents/shared/pkg/validator"
)

// UserServiceInterface интерфейс для UserService (для тестирования)
type UserServiceInterface interface {
	CreateUser(ctx context.Context, req *model.CreateUserRequest) (*model.User, error)
	GetUserByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error)
	GetUserByID(ctx context.Context, id string) (*model.User, error)
	UpdateUser(ctx context.Context, firebaseUID string, req *model.UpdateUserRequest) (*model.User, error)
	UpdateLocation(ctx context.Context, firebaseUID string, req *model.UpdateLocationRequest) error
	CompleteOnboarding(ctx context.Context, firebaseUID string, req *model.CompleteOnboardingRequest) (*model.User, error)
	GetMatches(ctx context.Context, firebaseUID string, latitude, longitude *float64, radiusKm, limit int) ([]*model.User, error)
}

// UserHandler HTTP handlers для пользователей
type UserHandler struct {
	userService UserServiceInterface
}

// NewUserHandler создаёт новый handler
func NewUserHandler(userService UserServiceInterface) *UserHandler {
	return &UserHandler{userService: userService}
}

// CreateUser создаёт пользователя
// POST /api/users
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req model.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	if err := validator.Validate(&req); err != nil {
		response.ValidationError(c, err)
		return
	}

	// Берём Firebase UID из токена если не передан
	if req.FirebaseUID == "" {
		firebaseUID, ok := middleware.GetFirebaseUID(c)
		if !ok {
			response.Unauthorized(c, "Firebase UID not found")
			return
		}
		req.FirebaseUID = firebaseUID
	}

	user, err := h.userService.CreateUser(c.Request.Context(), &req)
	if err != nil {
		if errors.Is(err, service.ErrUserAlreadyExists) {
			response.Conflict(c, "User with this email already exists")
			return
		}
		response.InternalError(c, "Failed to create user")
		return
	}

	response.Created(c, user.ToPrivateResponse())
}

// GetMe возвращает текущего пользователя
// GET /api/users/me
func (h *UserHandler) GetMe(c *gin.Context) {
	firebaseUID, ok := middleware.GetFirebaseUID(c)
	if !ok {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	user, err := h.userService.GetUserByFirebaseUID(c.Request.Context(), firebaseUID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found. Please complete registration.")
			return
		}
		response.InternalError(c, "Failed to get user")
		return
	}

	response.Success(c, user.ToPrivateResponse())
}

// UpdateMe обновляет текущего пользователя
// PUT /api/users/me
func (h *UserHandler) UpdateMe(c *gin.Context) {
	firebaseUID, ok := middleware.GetFirebaseUID(c)
	if !ok {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	var req model.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	if err := validator.Validate(&req); err != nil {
		response.ValidationError(c, err)
		return
	}

	user, err := h.userService.UpdateUser(c.Request.Context(), firebaseUID, &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found")
			return
		}
		response.InternalError(c, "Failed to update user")
		return
	}

	response.Success(c, user.ToPrivateResponse())
}

// UpdateLocation обновляет геолокацию
// PUT /api/users/me/location
func (h *UserHandler) UpdateLocation(c *gin.Context) {
	firebaseUID, ok := middleware.GetFirebaseUID(c)
	if !ok {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	var req model.UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	if err := validator.Validate(&req); err != nil {
		response.ValidationError(c, err)
		return
	}

	err := h.userService.UpdateLocation(c.Request.Context(), firebaseUID, &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found")
			return
		}
		response.InternalError(c, "Failed to update location")
		return
	}

	response.Success(c, gin.H{"message": "Location updated"})
}

// CompleteOnboarding завершает онбординг
// POST /api/users/me/onboarding
func (h *UserHandler) CompleteOnboarding(c *gin.Context) {
	firebaseUID, ok := middleware.GetFirebaseUID(c)
	if !ok {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	var req model.CompleteOnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	if err := validator.Validate(&req); err != nil {
		response.ValidationError(c, err)
		return
	}

	user, err := h.userService.CompleteOnboarding(c.Request.Context(), firebaseUID, &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found")
			return
		}
		response.InternalError(c, "Failed to complete onboarding")
		return
	}

	response.Success(c, user.ToPrivateResponse())
}

// GetUser возвращает пользователя по ID
// GET /api/users/:id
func (h *UserHandler) GetUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		response.BadRequest(c, "User ID is required")
		return
	}

	user, err := h.userService.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found")
			return
		}
		response.InternalError(c, "Failed to get user")
		return
	}

	response.Success(c, user.ToResponse())
}

// GetMatches возвращает потенциальных мэтчей
// GET /api/users/matches?latitude=...&longitude=...&radiusKm=...&limit=...
// Совместимо с Express API
func (h *UserHandler) GetMatches(c *gin.Context) {
	firebaseUID, ok := middleware.GetFirebaseUID(c)
	if !ok {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	// Параметры запроса (совместимо с Express)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	radiusKm, _ := strconv.Atoi(c.DefaultQuery("radiusKm", "50"))

	// Опциональные координаты (если не переданы - используем последние известные)
	var latitude, longitude *float64
	if latStr := c.Query("latitude"); latStr != "" {
		if lat, err := strconv.ParseFloat(latStr, 64); err == nil {
			latitude = &lat
		}
	}
	if lonStr := c.Query("longitude"); lonStr != "" {
		if lon, err := strconv.ParseFloat(lonStr, 64); err == nil {
			longitude = &lon
		}
	}

	// Валидация координат
	if latitude != nil && longitude != nil {
		if *latitude < -90 || *latitude > 90 || *longitude < -180 || *longitude > 180 {
			response.BadRequest(c, "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180")
			return
		}
	}

	if limit > 100 {
		limit = 100
	}
	if limit < 1 {
		limit = 20
	}

	users, err := h.userService.GetMatches(c.Request.Context(), firebaseUID, latitude, longitude, radiusKm, limit)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "User not found")
			return
		}
		response.InternalError(c, "Failed to get matches")
		return
	}

	response.Success(c, users)
}
