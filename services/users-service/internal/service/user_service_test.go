package service

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/users-service/internal/model"
)

// MockUserRepository мок для UserRepository
type MockUserRepository struct {
	mock.Mock
}

func (m *MockUserRepository) Create(ctx context.Context, supabaseUID, email string, displayName, photoURL *string) (*model.User, error) {
	args := m.Called(ctx, supabaseUID, email, displayName, photoURL)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) GetBySupabaseUID(ctx context.Context, supabaseUID string) (*model.User, error) {
	args := m.Called(ctx, supabaseUID)
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

func (m *MockUserRepository) Update(ctx context.Context, id string, req *model.UpdateUserRequest) (*model.User, error) {
	args := m.Called(ctx, id, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserRepository) UpdateLocation(ctx context.Context, id string, latitude, longitude float64) error {
	args := m.Called(ctx, id, latitude, longitude)
	return args.Error(0)
}

func (m *MockUserRepository) GetMatches(ctx context.Context, userID string, latitude, longitude *float64, radiusKm float64, limit int) ([]model.User, error) {
	args := m.Called(ctx, userID, latitude, longitude, radiusKm, limit)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.User), args.Error(1)
}

func (m *MockUserRepository) UpdateSupabaseUID(ctx context.Context, id, supabaseUID string) (*model.User, error) {
	args := m.Called(ctx, id, supabaseUID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.User), args.Error(1)
}

func TestCreateUser_NewUser(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	supabaseUID := "test-uid-123"
	email := "test@example.com"
	displayName := "Test User"

	expectedUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: supabaseUID,
		Email:       email,
		DisplayName: &displayName,
	}

	mockRepo.On("GetByEmail", ctx, email).Return(nil, nil)
	mockRepo.On("Create", ctx, supabaseUID, email, &displayName, (*string)(nil)).Return(expectedUser, nil)

	user, err := svc.CreateUser(ctx, supabaseUID, email, &displayName, nil)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, expectedUser.ID, user.ID)
	assert.Equal(t, expectedUser.Email, user.Email)
	mockRepo.AssertExpectations(t)
}

func TestCreateUser_ExistingUser_SameSupabaseUID(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	supabaseUID := "test-uid-123"
	email := "test@example.com"

	existingUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: supabaseUID,
		Email:       email,
	}

	mockRepo.On("GetByEmail", ctx, email).Return(existingUser, nil)

	user, err := svc.CreateUser(ctx, supabaseUID, email, nil, nil)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, existingUser.ID, user.ID)
	mockRepo.AssertExpectations(t)
}

func TestCreateUser_ExistingUser_DifferentSupabaseUID(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	supabaseUID := "new-uid-456"
	email := "test@example.com"

	existingUser := &model.User{
		ID:          "user-id-123",
		SupabaseUID: "old-uid-123",
		Email:       email,
	}

	mockRepo.On("GetByEmail", ctx, email).Return(existingUser, nil)

	user, err := svc.CreateUser(ctx, supabaseUID, email, nil, nil)

	assert.Error(t, err)
	assert.Equal(t, ErrUserAlreadyExists, err)
	assert.Nil(t, user)
	mockRepo.AssertExpectations(t)
}

func TestGetCurrentUser_Found(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"

	expectedUser := &model.User{
		ID:    userID,
		Email: "test@example.com",
	}

	mockRepo.On("GetByID", ctx, userID).Return(expectedUser, nil)

	user, err := svc.GetCurrentUser(ctx, userID)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, expectedUser.ID, user.ID)
	mockRepo.AssertExpectations(t)
}

func TestGetCurrentUser_NotFound(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "non-existent-id"

	mockRepo.On("GetByID", ctx, userID).Return(nil, nil)

	user, err := svc.GetCurrentUser(ctx, userID)

	assert.Error(t, err)
	assert.Equal(t, ErrUserNotFound, err)
	assert.Nil(t, user)
	mockRepo.AssertExpectations(t)
}

func TestUpdateProfile_Success(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"
	newName := "Updated Name"
	req := &model.UpdateUserRequest{
		DisplayName: &newName,
	}

	existingUser := &model.User{
		ID:    userID,
		Email: "test@example.com",
	}

	updatedUser := &model.User{
		ID:          userID,
		Email:       "test@example.com",
		DisplayName: &newName,
	}

	mockRepo.On("GetByID", ctx, userID).Return(existingUser, nil)
	mockRepo.On("Update", ctx, userID, req).Return(updatedUser, nil)

	user, err := svc.UpdateProfile(ctx, userID, req)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, newName, *user.DisplayName)
	mockRepo.AssertExpectations(t)
}

func TestUpdateLocation_Success(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"
	lat := 55.7558
	lon := 37.6173

	existingUser := &model.User{
		ID:    userID,
		Email: "test@example.com",
	}

	mockRepo.On("GetByID", ctx, userID).Return(existingUser, nil)
	mockRepo.On("UpdateLocation", ctx, userID, lat, lon).Return(nil)

	err := svc.UpdateLocation(ctx, userID, lat, lon)

	assert.NoError(t, err)
	mockRepo.AssertExpectations(t)
}

func TestUpdateLocation_InvalidCoordinates(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"

	// Latitude out of range
	err := svc.UpdateLocation(ctx, userID, 91.0, 37.6173)
	assert.Error(t, err)
	assert.Equal(t, ErrInvalidCoordinates, err)

	// Longitude out of range
	err = svc.UpdateLocation(ctx, userID, 55.7558, 181.0)
	assert.Error(t, err)
	assert.Equal(t, ErrInvalidCoordinates, err)
}

func TestGetMatches_Success(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"
	lat := 55.7558
	lon := 37.6173
	radiusKm := 50.0
	limit := 20

	existingUser := &model.User{
		ID:    userID,
		Email: "test@example.com",
	}

	expectedMatches := []model.User{
		{ID: "match-1", Email: "match1@example.com"},
		{ID: "match-2", Email: "match2@example.com"},
	}

	mockRepo.On("GetByID", ctx, userID).Return(existingUser, nil)
	mockRepo.On("GetMatches", ctx, userID, &lat, &lon, radiusKm, limit).Return(expectedMatches, nil)

	matches, err := svc.GetMatches(ctx, userID, &lat, &lon, radiusKm, limit)

	assert.NoError(t, err)
	assert.Len(t, matches, 2)
	mockRepo.AssertExpectations(t)
}

func TestGetMatches_UserNotFound(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "non-existent-id"
	lat := 55.7558
	lon := 37.6173

	mockRepo.On("GetByID", ctx, userID).Return(nil, nil)

	matches, err := svc.GetMatches(ctx, userID, &lat, &lon, 50.0, 20)

	assert.Error(t, err)
	assert.Equal(t, ErrUserNotFound, err)
	assert.Nil(t, matches)
	mockRepo.AssertExpectations(t)
}

func TestGetMatches_RepoError(t *testing.T) {
	mockRepo := new(MockUserRepository)
	logger, _ := zap.NewDevelopment()
	svc := NewUserService(mockRepo, logger)

	ctx := context.Background()
	userID := "user-id-123"
	lat := 55.7558
	lon := 37.6173

	existingUser := &model.User{
		ID:    userID,
		Email: "test@example.com",
	}

	mockRepo.On("GetByID", ctx, userID).Return(existingUser, nil)
	mockRepo.On("GetMatches", ctx, userID, &lat, &lon, 50.0, 20).Return(nil, errors.New("database error"))

	matches, err := svc.GetMatches(ctx, userID, &lat, &lon, 50.0, 20)

	assert.Error(t, err)
	assert.Nil(t, matches)
	mockRepo.AssertExpectations(t)
}
