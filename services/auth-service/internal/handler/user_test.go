package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/model"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/service"
)

// Ключ для firebase UID в контексте (должен совпадать с middleware.FirebaseUIDKey)
const firebaseUIDKey = "firebaseUID"

// MockUserService - мок сервиса для тестирования хэндлеров
type MockUserService struct {
	mock.Mock
}

func (m *MockUserService) CreateUser(ctx context.Context, req *model.CreateUserRequest) (*model.User, error) {
	args := m.Called(ctx, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserService) GetUserByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error) {
	args := m.Called(ctx, firebaseUID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserService) GetUserByID(ctx context.Context, id string) (*model.User, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserService) UpdateUser(ctx context.Context, firebaseUID string, req *model.UpdateUserRequest) (*model.User, error) {
	args := m.Called(ctx, firebaseUID, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserService) UpdateLocation(ctx context.Context, firebaseUID string, req *model.UpdateLocationRequest) error {
	args := m.Called(ctx, firebaseUID, req)
	return args.Error(0)
}

func (m *MockUserService) CompleteOnboarding(ctx context.Context, firebaseUID string, req *model.CompleteOnboardingRequest) (*model.User, error) {
	args := m.Called(ctx, firebaseUID, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserService) GetMatches(ctx context.Context, firebaseUID string, latitude, longitude *float64, radiusKm, limit int) ([]*model.User, error) {
	args := m.Called(ctx, firebaseUID, latitude, longitude, radiusKm, limit)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*model.User), args.Error(1)
}

func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	return gin.New()
}

func setUserContext(c *gin.Context, firebaseUID string) {
	c.Set(firebaseUIDKey, firebaseUID)
}

// TestCreateUser_Success тестирует успешное создание пользователя
func TestCreateUser_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()
	router.POST("/api/users", handler.CreateUser)

	reqBody := model.CreateUserRequest{
		FirebaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}
	body, _ := json.Marshal(reqBody)

	createdUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}
	mockService.On("CreateUser", mock.Anything, mock.MatchedBy(func(req *model.CreateUserRequest) bool {
		return req.FirebaseUID == "firebase-uid-123" && req.Email == "test@example.com"
	})).Return(createdUser, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/users", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusCreated, w.Code)
	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.True(t, response["success"].(bool))
	mockService.AssertExpectations(t)
}

// TestCreateUser_ValidationError тестирует валидацию
func TestCreateUser_ValidationError(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()
	router.POST("/api/users", handler.CreateUser)

	reqBody := model.CreateUserRequest{
		FirebaseUID: "",
		Email:       "",
	}
	body, _ := json.Marshal(reqBody)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/users", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// TestGetMe_Success тестирует получение текущего пользователя
func TestGetMe_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.GET("/api/users/me", func(c *gin.Context) {
		setUserContext(c, "firebase-uid-123")
		handler.GetMe(c)
	})

	expectedUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}
	mockService.On("GetUserByFirebaseUID", mock.Anything, "firebase-uid-123").Return(expectedUser, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/users/me", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestGetMe_NotFound тестирует когда пользователь не найден
func TestGetMe_NotFound(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.GET("/api/users/me", func(c *gin.Context) {
		setUserContext(c, "unknown-uid")
		handler.GetMe(c)
	})

	mockService.On("GetUserByFirebaseUID", mock.Anything, "unknown-uid").Return(nil, service.ErrUserNotFound)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/users/me", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)
	mockService.AssertExpectations(t)
}

// TestUpdateMe_Success тестирует обновление профиля
func TestUpdateMe_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.PUT("/api/users/me", func(c *gin.Context) {
		setUserContext(c, "firebase-uid-123")
		handler.UpdateMe(c)
	})

	displayName := "New Name"
	reqBody := model.UpdateUserRequest{
		DisplayName: &displayName,
	}
	body, _ := json.Marshal(reqBody)

	updatedUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		DisplayName: &displayName,
	}
	mockService.On("UpdateUser", mock.Anything, "firebase-uid-123", mock.Anything).Return(updatedUser, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("PUT", "/api/users/me", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestUpdateLocation_Success тестирует обновление геолокации
func TestUpdateLocation_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.PUT("/api/users/me/location", func(c *gin.Context) {
		setUserContext(c, "firebase-uid-123")
		handler.UpdateLocation(c)
	})

	reqBody := model.UpdateLocationRequest{
		Latitude:  55.7558,
		Longitude: 37.6173,
	}
	body, _ := json.Marshal(reqBody)

	mockService.On("UpdateLocation", mock.Anything, "firebase-uid-123", mock.MatchedBy(func(req *model.UpdateLocationRequest) bool {
		return req.Latitude == 55.7558 && req.Longitude == 37.6173
	})).Return(nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("PUT", "/api/users/me/location", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestGetMatches_Success тестирует получение мэтчей
func TestGetMatches_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.GET("/api/users/matches", func(c *gin.Context) {
		setUserContext(c, "firebase-uid-123")
		handler.GetMatches(c)
	})

	matches := []*model.User{
		{ID: "match-1", Email: "match1@example.com"},
		{ID: "match-2", Email: "match2@example.com"},
	}
	mockService.On("GetMatches", mock.Anything, "firebase-uid-123", mock.Anything, mock.Anything, 50, 20).Return(matches, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/users/matches?radiusKm=50&limit=20", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestCompleteOnboarding_Success тестирует завершение онбординга
func TestCompleteOnboarding_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()

	router.POST("/api/users/me/onboarding", func(c *gin.Context) {
		setUserContext(c, "firebase-uid-123")
		handler.CompleteOnboarding(c)
	})

	displayName := "Test User"
	age := 25
	reqBody := model.CompleteOnboardingRequest{
		DisplayName: &displayName,
		Age:         &age,
	}
	body, _ := json.Marshal(reqBody)

	completedUser := &model.User{
		ID:                    "user-id-123",
		SupabaseUID:           "firebase-uid-123",
		DisplayName:           &displayName,
		Age:                   &age,
		IsOnboardingCompleted: true,
	}
	mockService.On("CompleteOnboarding", mock.Anything, "firebase-uid-123", mock.Anything).Return(completedUser, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/users/me/onboarding", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestGetUser_Success тестирует получение пользователя по ID
func TestGetUser_Success(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()
	router.GET("/api/users/:id", handler.GetUser)

	expectedUser := &model.User{
		ID:    "user-id-123",
		Email: "test@example.com",
	}
	mockService.On("GetUserByID", mock.Anything, "user-id-123").Return(expectedUser, nil)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/users/user-id-123", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockService.AssertExpectations(t)
}

// TestGetUser_NotFound тестирует когда пользователь не найден
func TestGetUser_NotFound(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()
	router.GET("/api/users/:id", handler.GetUser)

	mockService.On("GetUserByID", mock.Anything, "unknown-id").Return(nil, service.ErrUserNotFound)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/users/unknown-id", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)
	mockService.AssertExpectations(t)
}

// TestInvalidJSON тестирует обработку невалидного JSON
func TestInvalidJSON(t *testing.T) {
	mockService := new(MockUserService)
	handler := NewUserHandler(mockService)
	router := setupTestRouter()
	router.POST("/api/users", handler.CreateUser)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/users", bytes.NewBufferString("not valid json"))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}
