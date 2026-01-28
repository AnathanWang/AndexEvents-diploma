package service

import (
	"context"
	"errors"

	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/model"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/repository"
	"github.com/AnathanWang/andexevents/shared/pkg/logger"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrUserAlreadyExists = errors.New("user already exists")
)

// UserService бизнес-логика для пользователей
type UserService struct {
	userRepo repository.UserRepository
}

// NewUserService создаёт новый сервис
func NewUserService(userRepo repository.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

// CreateUser создаёт пользователя
func (s *UserService) CreateUser(ctx context.Context, req *model.CreateUserRequest) (*model.User, error) {
	// Проверяем существование по Firebase UID
	existing, err := s.userRepo.GetByFirebaseUID(ctx, req.FirebaseUID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		logger.Info("User already exists", zap.String("firebaseUID", req.FirebaseUID))
		return existing, nil
	}

	// Проверяем email
	existing, err = s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, ErrUserAlreadyExists
	}

	user := &model.User{
		SupabaseUID: req.FirebaseUID,
		Email:       req.Email,
		DisplayName: req.DisplayName,
		PhotoURL:    req.PhotoURL,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

// GetUserByFirebaseUID возвращает пользователя по Firebase UID
func (s *UserService) GetUserByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error) {
	user, err := s.userRepo.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	return user, nil
}

// GetUserByID возвращает пользователя по ID
func (s *UserService) GetUserByID(ctx context.Context, id string) (*model.User, error) {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	return user, nil
}

// UpdateUser обновляет профиль
func (s *UserService) UpdateUser(ctx context.Context, firebaseUID string, req *model.UpdateUserRequest) (*model.User, error) {
	user, err := s.userRepo.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	// Partial update
	if req.DisplayName != nil {
		user.DisplayName = req.DisplayName
	}
	if req.PhotoURL != nil {
		user.PhotoURL = req.PhotoURL
	}
	if req.Bio != nil {
		user.Bio = req.Bio
	}
	if req.Interests != nil {
		user.Interests = req.Interests
	}
	if req.SocialLinks != nil {
		user.SocialLinks = req.SocialLinks
	}
	if req.Age != nil {
		user.Age = req.Age
	}
	if req.Gender != nil {
		user.Gender = req.Gender
	}
	if req.MinAge != nil {
		user.MinAge = req.MinAge
	}
	if req.MaxAge != nil {
		user.MaxAge = req.MaxAge
	}
	if req.MaxDistance != nil {
		user.MaxDistance = *req.MaxDistance
	}
	if req.FCMToken != nil {
		user.FCMToken = req.FCMToken
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

// UpdateLocation обновляет геолокацию
func (s *UserService) UpdateLocation(ctx context.Context, firebaseUID string, req *model.UpdateLocationRequest) error {
	user, err := s.userRepo.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	return s.userRepo.UpdateLocation(ctx, user.ID, req.Latitude, req.Longitude)
}

// CompleteOnboarding завершает онбординг
func (s *UserService) CompleteOnboarding(ctx context.Context, firebaseUID string, req *model.CompleteOnboardingRequest) (*model.User, error) {
	user, err := s.userRepo.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if req.DisplayName != nil {
		user.DisplayName = req.DisplayName
	}
	if req.Bio != nil {
		user.Bio = req.Bio
	}
	if req.Interests != nil {
		user.Interests = req.Interests
	}
	if req.Age != nil {
		user.Age = req.Age
	}
	if req.Gender != nil {
		user.Gender = req.Gender
	}

	user.IsOnboardingCompleted = true

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

// GetMatches возвращает потенциальных мэтчей
// latitude/longitude опциональны - если nil, используются последние координаты пользователя
func (s *UserService) GetMatches(ctx context.Context, firebaseUID string, latitude, longitude *float64, radiusKm, limit int) ([]*model.User, error) {
	user, err := s.userRepo.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	// Используем переданные координаты или последние известные
	userLat := latitude
	userLon := longitude
	if userLat == nil {
		userLat = user.LastLatitude
	}
	if userLon == nil {
		userLon = user.LastLongitude
	}

	// Если координаты не доступны - возвращаем пустой список
	if userLat == nil || userLon == nil {
		logger.Warn("No location available for user", zap.String("userID", user.ID))
		return []*model.User{}, nil
	}

	return s.userRepo.GetMatches(ctx, user.ID, *userLat, *userLon, radiusKm, limit, user.MinAge, user.MaxAge)
}
