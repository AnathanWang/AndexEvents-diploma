package service

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/model"
)

// MockUserRepository - мок репозитория для тестирования
// Моки позволяют изолировать тесты от базы данных
// Мы контролируем что возвращает "база данных"
type MockUserRepository struct {
	mock.Mock
}

func (m *MockUserRepository) Create(ctx context.Context, user *model.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) GetByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error) {
	args := m.Called(ctx, firebaseUID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	args := m.Called(ctx, email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) Update(ctx context.Context, user *model.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) UpdateLocation(ctx context.Context, id string, lat, lng float64) error {
	args := m.Called(ctx, id, lat, lng)
	return args.Error(0)
}

func (m *MockUserRepository) Delete(ctx context.Context, id string) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockUserRepository) GetPotentialMatches(ctx context.Context, userID string, limit, offset int) ([]*model.User, error) {
	args := m.Called(ctx, userID, limit, offset)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*model.User), args.Error(1)
}

func (m *MockUserRepository) GetMatches(ctx context.Context, userID string, lat, lon float64, radiusKm, limit int, minAge, maxAge *int) ([]*model.User, error) {
	args := m.Called(ctx, userID, lat, lon, radiusKm, limit, minAge, maxAge)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*model.User), args.Error(1)
}

// TestCreateUser_NewUser проверяет создание нового пользователя
func TestCreateUser_NewUser(t *testing.T) {
	// Arrange - подготовка
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	req := &model.CreateUserRequest{
		FirebaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}

	// Настраиваем мок: пользователь не существует
	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(nil, nil)
	mockRepo.On("GetByEmail", ctx, "test@example.com").Return(nil, nil)
	mockRepo.On("Create", ctx, mock.AnythingOfType("*model.User")).Return(nil)

	// Act - действие
	user, err := service.CreateUser(ctx, req)

	// Assert - проверка
	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, "firebase-uid-123", user.SupabaseUID)
	assert.Equal(t, "test@example.com", user.Email)
	mockRepo.AssertExpectations(t)
}

// TestCreateUser_ExistingUser проверяет что при повторной регистрации
// возвращается существующий пользователь (idempotent)
func TestCreateUser_ExistingUser(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	existingUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}

	req := &model.CreateUserRequest{
		FirebaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}

	// Пользователь уже существует
	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(existingUser, nil)

	// Act
	user, err := service.CreateUser(ctx, req)

	// Assert - должен вернуть существующего пользователя без ошибки
	assert.NoError(t, err)
	assert.Equal(t, existingUser.ID, user.ID)
	mockRepo.AssertExpectations(t)
}

// TestCreateUser_EmailConflict проверяет ошибку при конфликте email
func TestCreateUser_EmailConflict(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	existingUser := &model.User{
		ID:          "other-user-id",
		SupabaseUID: "other-firebase-uid",
		Email:       "test@example.com",
	}

	req := &model.CreateUserRequest{
		FirebaseUID: "new-firebase-uid",
		Email:       "test@example.com", // Тот же email
	}

	mockRepo.On("GetByFirebaseUID", ctx, "new-firebase-uid").Return(nil, nil)
	mockRepo.On("GetByEmail", ctx, "test@example.com").Return(existingUser, nil)

	// Act
	user, err := service.CreateUser(ctx, req)

	// Assert - должна быть ошибка конфликта
	assert.Error(t, err)
	assert.Equal(t, ErrUserAlreadyExists, err)
	assert.Nil(t, user)
	mockRepo.AssertExpectations(t)
}

// TestGetUserByFirebaseUID_Found проверяет получение существующего пользователя
func TestGetUserByFirebaseUID_Found(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	expectedUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(expectedUser, nil)

	// Act
	user, err := service.GetUserByFirebaseUID(ctx, "firebase-uid-123")

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, expectedUser.ID, user.ID)
	mockRepo.AssertExpectations(t)
}

// TestGetUserByFirebaseUID_NotFound проверяет ошибку когда пользователь не найден
func TestGetUserByFirebaseUID_NotFound(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	mockRepo.On("GetByFirebaseUID", ctx, "unknown-uid").Return(nil, nil)

	// Act
	user, err := service.GetUserByFirebaseUID(ctx, "unknown-uid")

	// Assert
	assert.Error(t, err)
	assert.Equal(t, ErrUserNotFound, err)
	assert.Nil(t, user)
	mockRepo.AssertExpectations(t)
}

// TestUpdateUser_Success проверяет успешное обновление профиля
func TestUpdateUser_Success(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	existingUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
		Email:       "test@example.com",
	}

	displayName := "New Name"
	bio := "New bio"
	req := &model.UpdateUserRequest{
		DisplayName: &displayName,
		Bio:         &bio,
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(existingUser, nil)
	mockRepo.On("Update", ctx, mock.AnythingOfType("*model.User")).Return(nil)

	// Act
	user, err := service.UpdateUser(ctx, "firebase-uid-123", req)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, "New Name", *user.DisplayName)
	assert.Equal(t, "New bio", *user.Bio)
	mockRepo.AssertExpectations(t)
}

// TestUpdateLocation_Success проверяет обновление геолокации
func TestUpdateLocation_Success(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	existingUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "firebase-uid-123",
	}

	req := &model.UpdateLocationRequest{
		Latitude:  55.7558,
		Longitude: 37.6173,
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(existingUser, nil)
	mockRepo.On("UpdateLocation", ctx, "user-id-123", 55.7558, 37.6173).Return(nil)

	// Act
	err := service.UpdateLocation(ctx, "firebase-uid-123", req)

	// Assert
	assert.NoError(t, err)
	mockRepo.AssertExpectations(t)
}

// TestGetMatches_Success проверяет получение мэтчей
func TestGetMatches_Success(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	lat := 55.7558
	lon := 37.6173

	currentUser := &model.User{
		ID:            "user-id-123",
		SupabaseUID:   "firebase-uid-123",
		LastLatitude:  &lat,
		LastLongitude: &lon,
	}

	expectedMatches := []*model.User{
		{ID: "match-1", Email: "match1@example.com"},
		{ID: "match-2", Email: "match2@example.com"},
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(currentUser, nil)
	mockRepo.On("GetMatches", ctx, "user-id-123", lat, lon, 50, 20, (*int)(nil), (*int)(nil)).Return(expectedMatches, nil)

	// Act
	matches, err := service.GetMatches(ctx, "firebase-uid-123", &lat, &lon, 50, 20)

	// Assert
	assert.NoError(t, err)
	assert.Len(t, matches, 2)
	mockRepo.AssertExpectations(t)
}

// TestGetMatches_NoLocation проверяет что без локации возвращается пустой список
func TestGetMatches_NoLocation(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	// Пользователь без локации
	currentUser := &model.User{
		ID:            "user-id-123",
		SupabaseUID:   "firebase-uid-123",
		LastLatitude:  nil,
		LastLongitude: nil,
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(currentUser, nil)

	// Act - не передаём координаты и у пользователя их нет
	matches, err := service.GetMatches(ctx, "firebase-uid-123", nil, nil, 50, 20)

	// Assert - должен вернуть пустой список без ошибки
	assert.NoError(t, err)
	assert.Empty(t, matches)
	mockRepo.AssertExpectations(t)
}

// TestCompleteOnboarding_Success проверяет завершение онбординга
func TestCompleteOnboarding_Success(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	existingUser := &model.User{
		ID:                    "user-id-123",
		SupabaseUID:           "firebase-uid-123",
		IsOnboardingCompleted: false,
	}

	displayName := "Test User"
	age := 25
	req := &model.CompleteOnboardingRequest{
		DisplayName: &displayName,
		Age:         &age,
	}

	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(existingUser, nil)
	mockRepo.On("Update", ctx, mock.AnythingOfType("*model.User")).Return(nil)

	// Act
	user, err := service.CompleteOnboarding(ctx, "firebase-uid-123", req)

	// Assert
	assert.NoError(t, err)
	assert.True(t, user.IsOnboardingCompleted)
	assert.Equal(t, "Test User", *user.DisplayName)
	assert.Equal(t, 25, *user.Age)
	mockRepo.AssertExpectations(t)
}

// TestRepository_Error проверяет обработку ошибок репозитория
func TestRepository_Error(t *testing.T) {
	// Arrange
	mockRepo := new(MockUserRepository)
	service := NewUserService(mockRepo)
	ctx := context.Background()

	dbError := errors.New("database connection failed")
	mockRepo.On("GetByFirebaseUID", ctx, "firebase-uid-123").Return(nil, dbError)

	// Act
	user, err := service.GetUserByFirebaseUID(ctx, "firebase-uid-123")

	// Assert - ошибка БД должна пробрасываться
	assert.Error(t, err)
	assert.Equal(t, dbError, err)
	assert.Nil(t, user)
	mockRepo.AssertExpectations(t)
}
