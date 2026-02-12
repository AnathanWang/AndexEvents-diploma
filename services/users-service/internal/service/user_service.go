package service

import (
	"context"
	"errors"

	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/users-service/internal/model"
	"github.com/AnathanWang/andexevents/services/users-service/internal/repository"
)

// Ошибки сервиса
var (
	ErrUserNotFound       = errors.New("user not found")
	ErrUserAlreadyExists  = errors.New("user with this email already exists")
	ErrInvalidCoordinates = errors.New("invalid coordinates")
	ErrNoLocation         = errors.New("no location available")
)

// UserService интерфейс сервиса пользователей
type UserService interface {
	CreateUser(ctx context.Context, supabaseUID, email string, displayName, photoURL *string) (*model.User, error)
	GetCurrentUser(ctx context.Context, userID string) (*model.User, error)
	GetUserBySupabaseUID(ctx context.Context, supabaseUID string) (*model.User, error)
	UpdateProfile(ctx context.Context, userID string, req *model.UpdateUserRequest) (*model.User, error)
	UpdateLocation(ctx context.Context, userID string, latitude, longitude float64) error
	GetMatches(ctx context.Context, userID string, latitude, longitude *float64, radiusKm float64, limit int) ([]model.User, error)
}

type userService struct {
	repo   repository.UserRepository
	logger *zap.Logger
}

// NewUserService создаёт новый сервис пользователей
func NewUserService(repo repository.UserRepository, logger *zap.Logger) UserService {
	return &userService{
		repo:   repo,
		logger: logger,
	}
}

// CreateUser создаёт нового пользователя
func (s *userService) CreateUser(ctx context.Context, supabaseUID, email string, displayName, photoURL *string) (*model.User, error) {
	s.logger.Info("Creating user",
		zap.String("supabaseUID", supabaseUID),
		zap.String("email", email),
	)

	// Проверяем существует ли пользователь с таким email
	existingUser, err := s.repo.GetByEmail(ctx, email)
	if err != nil {
		s.logger.Error("Error checking existing user", zap.Error(err))
		return nil, err
	}

	if existingUser != nil {
		s.logger.Info("User already exists with email", zap.String("email", email))

		// Если supabaseUid пустой - обновляем
		if existingUser.SupabaseUID == "" {
			s.logger.Info("Updating existing user with supabaseUid",
				zap.String("userID", existingUser.ID),
				zap.String("supabaseUID", supabaseUID),
			)
			return s.repo.UpdateSupabaseUID(ctx, existingUser.ID, supabaseUID)
		}

		// Если supabaseUid совпадает - возвращаем пользователя
		if existingUser.SupabaseUID == supabaseUID {
			return existingUser, nil
		}

		// Если supabaseUid отличается - это конфликт
		return nil, ErrUserAlreadyExists
	}

	// Создаём нового пользователя
	user, err := s.repo.Create(ctx, supabaseUID, email, displayName, photoURL)
	if err != nil {
		s.logger.Error("Error creating user", zap.Error(err))
		return nil, err
	}

	s.logger.Info("User created successfully", zap.String("userID", user.ID))
	return user, nil
}

// GetCurrentUser получает текущего пользователя по ID из БД
func (s *userService) GetCurrentUser(ctx context.Context, userID string) (*model.User, error) {
	s.logger.Info("Getting user", zap.String("userID", userID))

	user, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		s.logger.Error("Error getting user", zap.Error(err))
		return nil, err
	}

	if user == nil {
		s.logger.Warn("User not found", zap.String("userID", userID))
		return nil, ErrUserNotFound
	}

	return user, nil
}

// GetUserBySupabaseUID получает пользователя по Supabase UID
func (s *userService) GetUserBySupabaseUID(ctx context.Context, supabaseUID string) (*model.User, error) {
	s.logger.Info("Getting user by supabaseUID", zap.String("supabaseUID", supabaseUID))

	user, err := s.repo.GetBySupabaseUID(ctx, supabaseUID)
	if err != nil {
		s.logger.Error("Error getting user by supabaseUID", zap.Error(err))
		return nil, err
	}

	if user == nil {
		s.logger.Warn("User not found", zap.String("supabaseUID", supabaseUID))
		return nil, ErrUserNotFound
	}

	return user, nil
}

// UpdateProfile обновляет профиль пользователя
func (s *userService) UpdateProfile(ctx context.Context, userID string, req *model.UpdateUserRequest) (*model.User, error) {
	s.logger.Info("Updating user profile", zap.String("userID", userID))

	// Проверяем существование пользователя
	existing, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		s.logger.Error("Error checking user existence", zap.Error(err))
		return nil, err
	}
	if existing == nil {
		return nil, ErrUserNotFound
	}

	user, err := s.repo.Update(ctx, userID, req)
	if err != nil {
		s.logger.Error("Error updating user profile", zap.Error(err))
		return nil, err
	}

	s.logger.Info("User profile updated successfully", zap.String("userID", userID))
	return user, nil
}

// UpdateLocation обновляет геолокацию пользователя
func (s *userService) UpdateLocation(ctx context.Context, userID string, latitude, longitude float64) error {
	s.logger.Info("Updating user location",
		zap.String("userID", userID),
		zap.Float64("latitude", latitude),
		zap.Float64("longitude", longitude),
	)

	// Валидация координат
	if latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 {
		return ErrInvalidCoordinates
	}

	// Проверяем существование пользователя
	existing, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		s.logger.Error("Error checking user existence", zap.Error(err))
		return err
	}
	if existing == nil {
		return ErrUserNotFound
	}

	err = s.repo.UpdateLocation(ctx, userID, latitude, longitude)
	if err != nil {
		s.logger.Error("Error updating location", zap.Error(err))
		return err
	}

	s.logger.Info("User location updated successfully", zap.String("userID", userID))
	return nil
}

// GetMatches получает список потенциальных матчей
func (s *userService) GetMatches(ctx context.Context, userID string, latitude, longitude *float64, radiusKm float64, limit int) ([]model.User, error) {
	s.logger.Info("Getting matches for user",
		zap.String("userID", userID),
		zap.Float64p("latitude", latitude),
		zap.Float64p("longitude", longitude),
		zap.Float64("radiusKm", radiusKm),
		zap.Int("limit", limit),
	)

	// Проверяем существование пользователя
	existing, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		s.logger.Error("Error checking user existence", zap.Error(err))
		return nil, err
	}
	if existing == nil {
		return nil, ErrUserNotFound
	}

	matches, err := s.repo.GetMatches(ctx, userID, latitude, longitude, radiusKm, limit)
	if err != nil {
		s.logger.Error("Error getting matches", zap.Error(err))
		return nil, err
	}

	s.logger.Info("Found matches", zap.String("userID", userID), zap.Int("count", len(matches)))
	return matches, nil
}
