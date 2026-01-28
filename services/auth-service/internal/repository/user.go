package repository

import (
	"context"
	"errors"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/model"
	"github.com/AnathanWang/andexevents/shared/pkg/logger"
)

// UserRepository интерфейс для работы с пользователями
type UserRepository interface {
	Create(ctx context.Context, user *model.User) error
	GetByID(ctx context.Context, id string) (*model.User, error)
	GetByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error)
	GetByEmail(ctx context.Context, email string) (*model.User, error)
	Update(ctx context.Context, user *model.User) error
	UpdateLocation(ctx context.Context, id string, lat, lng float64) error
	Delete(ctx context.Context, id string) error
	GetPotentialMatches(ctx context.Context, userID string, limit, offset int) ([]*model.User, error)
	GetMatches(ctx context.Context, userID string, lat, lon float64, radiusKm, limit int, minAge, maxAge *int) ([]*model.User, error)
}

type userRepository struct {
	db *pgxpool.Pool
}

// NewUserRepository создаёт новый репозиторий
func NewUserRepository(db *pgxpool.Pool) UserRepository {
	return &userRepository{db: db}
}

// Create создаёт нового пользователя
func (r *userRepository) Create(ctx context.Context, user *model.User) error {
	user.ID = uuid.New().String()
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()
	user.Role = model.UserRoleUser
	user.IsProfileVisible = true
	user.IsLocationVisible = true
	user.MaxDistance = 50000
	user.IsOnboardingCompleted = false

	// SQL с именами колонок Prisma (camelCase в кавычках)
	query := `
		INSERT INTO "User" (
			id, "supabaseUid", email, "displayName", "photoUrl",
			role, "isProfileVisible", "isLocationVisible", "maxDistance",
			"isOnboardingCompleted", "createdAt", "updatedAt"
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	_, err := r.db.Exec(ctx, query,
		user.ID,
		user.SupabaseUID,
		user.Email,
		user.DisplayName,
		user.PhotoURL,
		user.Role,
		user.IsProfileVisible,
		user.IsLocationVisible,
		user.MaxDistance,
		user.IsOnboardingCompleted,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		logger.Error("Failed to create user", zap.Error(err), zap.String("email", user.Email))
		return err
	}

	logger.Info("User created", zap.String("id", user.ID), zap.String("email", user.Email))
	return nil
}

// GetByID получает пользователя по ID
func (r *userRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	return r.getByField(ctx, "id", id)
}

// GetByFirebaseUID получает пользователя по Firebase UID
func (r *userRepository) GetByFirebaseUID(ctx context.Context, firebaseUID string) (*model.User, error) {
	return r.getByField(ctx, `"supabaseUid"`, firebaseUID)
}

// GetByEmail получает пользователя по email
func (r *userRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	return r.getByField(ctx, "email", email)
}

func (r *userRepository) getByField(ctx context.Context, field, value string) (*model.User, error) {
	query := `
		SELECT 
			id, "supabaseUid", email, "displayName", "photoUrl", bio,
			interests, "socialLinks", age, gender, role,
			"lastLatitude", "lastLongitude", "lastLocationUpdate",
			"isProfileVisible", "isLocationVisible", "minAge", "maxAge", "maxDistance",
			"fcmToken", "isOnboardingCompleted", "createdAt", "updatedAt"
		FROM "User"
		WHERE ` + field + ` = $1
	`

	var user model.User
	err := r.db.QueryRow(ctx, query, value).Scan(
		&user.ID,
		&user.SupabaseUID,
		&user.Email,
		&user.DisplayName,
		&user.PhotoURL,
		&user.Bio,
		&user.Interests,
		&user.SocialLinks,
		&user.Age,
		&user.Gender,
		&user.Role,
		&user.LastLatitude,
		&user.LastLongitude,
		&user.LastLocationUpdate,
		&user.IsProfileVisible,
		&user.IsLocationVisible,
		&user.MinAge,
		&user.MaxAge,
		&user.MaxDistance,
		&user.FCMToken,
		&user.IsOnboardingCompleted,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		logger.Error("Failed to get user", zap.Error(err), zap.String("field", field))
		return nil, err
	}

	return &user, nil
}

// Update обновляет пользователя
func (r *userRepository) Update(ctx context.Context, user *model.User) error {
	user.UpdatedAt = time.Now()

	query := `
		UPDATE "User" SET
			"displayName" = $2,
			"photoUrl" = $3,
			bio = $4,
			interests = $5,
			"socialLinks" = $6,
			age = $7,
			gender = $8,
			"isProfileVisible" = $9,
			"isLocationVisible" = $10,
			"minAge" = $11,
			"maxAge" = $12,
			"maxDistance" = $13,
			"fcmToken" = $14,
			"isOnboardingCompleted" = $15,
			"updatedAt" = $16
		WHERE id = $1
	`

	result, err := r.db.Exec(ctx, query,
		user.ID,
		user.DisplayName,
		user.PhotoURL,
		user.Bio,
		user.Interests,
		user.SocialLinks,
		user.Age,
		user.Gender,
		user.IsProfileVisible,
		user.IsLocationVisible,
		user.MinAge,
		user.MaxAge,
		user.MaxDistance,
		user.FCMToken,
		user.IsOnboardingCompleted,
		user.UpdatedAt,
	)

	if err != nil {
		logger.Error("Failed to update user", zap.Error(err), zap.String("id", user.ID))
		return err
	}

	if result.RowsAffected() == 0 {
		return errors.New("user not found")
	}

	return nil
}

// UpdateLocation обновляет геолокацию
func (r *userRepository) UpdateLocation(ctx context.Context, id string, lat, lng float64) error {
	query := `
		UPDATE "User" SET
			"lastLatitude" = $2,
			"lastLongitude" = $3,
			"lastLocationUpdate" = $4,
			"updatedAt" = $4
		WHERE id = $1
	`

	now := time.Now()
	result, err := r.db.Exec(ctx, query, id, lat, lng, now)

	if err != nil {
		logger.Error("Failed to update location", zap.Error(err), zap.String("id", id))
		return err
	}

	if result.RowsAffected() == 0 {
		return errors.New("user not found")
	}

	return nil
}

// Delete удаляет пользователя
func (r *userRepository) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM "User" WHERE id = $1`

	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		logger.Error("Failed to delete user", zap.Error(err), zap.String("id", id))
		return err
	}

	if result.RowsAffected() == 0 {
		return errors.New("user not found")
	}

	return nil
}

// GetPotentialMatches получает потенциальных мэтчей
func (r *userRepository) GetPotentialMatches(ctx context.Context, userID string, limit, offset int) ([]*model.User, error) {
	currentUser, err := r.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if currentUser == nil {
		return nil, errors.New("user not found")
	}

	if currentUser.LastLatitude == nil || currentUser.LastLongitude == nil {
		return []*model.User{}, nil
	}

	// Формула Haversine для расчёта расстояния
	query := `
		SELECT 
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", u.bio,
			u.interests, u."socialLinks", u.age, u.gender, u.role,
			u."lastLatitude", u."lastLongitude", u."lastLocationUpdate",
			u."isProfileVisible", u."isLocationVisible", u."minAge", u."maxAge", u."maxDistance",
			u."fcmToken", u."isOnboardingCompleted", u."createdAt", u."updatedAt"
		FROM "User" u
		WHERE u.id != $1
			AND u."isProfileVisible" = true
			AND u."lastLatitude" IS NOT NULL
			AND u."lastLongitude" IS NOT NULL
			AND NOT EXISTS (
				SELECT 1 FROM "Match" m
				WHERE (m."userAId" = $1 AND m."userBId" = u.id)
				   OR (m."userAId" = u.id AND m."userBId" = $1)
			)
			AND ($2::int IS NULL OR u.age >= $2)
			AND ($3::int IS NULL OR u.age <= $3)
			AND (
				6371000 * acos(
					cos(radians($4)) * cos(radians(u."lastLatitude")) *
					cos(radians(u."lastLongitude") - radians($5)) +
					sin(radians($4)) * sin(radians(u."lastLatitude"))
				)
			) <= $6
		ORDER BY "lastLocationUpdate" DESC NULLS LAST
		LIMIT $7 OFFSET $8
	`

	rows, err := r.db.Query(ctx, query,
		userID,
		currentUser.MinAge,
		currentUser.MaxAge,
		*currentUser.LastLatitude,
		*currentUser.LastLongitude,
		currentUser.MaxDistance,
		limit,
		offset,
	)
	if err != nil {
		logger.Error("Failed to get potential matches", zap.Error(err))
		return nil, err
	}
	defer rows.Close()

	var users []*model.User
	for rows.Next() {
		var user model.User
		err := rows.Scan(
			&user.ID,
			&user.SupabaseUID,
			&user.Email,
			&user.DisplayName,
			&user.PhotoURL,
			&user.Bio,
			&user.Interests,
			&user.SocialLinks,
			&user.Age,
			&user.Gender,
			&user.Role,
			&user.LastLatitude,
			&user.LastLongitude,
			&user.LastLocationUpdate,
			&user.IsProfileVisible,
			&user.IsLocationVisible,
			&user.MinAge,
			&user.MaxAge,
			&user.MaxDistance,
			&user.FCMToken,
			&user.IsOnboardingCompleted,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			continue
		}
		users = append(users, &user)
	}

	return users, nil
}

// GetMatches возвращает потенциальных мэтчей (совместимо с Express API)
// Использует переданные координаты и радиус для поиска
func (r *userRepository) GetMatches(ctx context.Context, userID string, lat, lon float64, radiusKm, limit int, minAge, maxAge *int) ([]*model.User, error) {
	// Вычисляем границы поиска (приближённо, как в Express)
	// Это проще чем PostGIS для совместимости
	earthRadiusKm := 6371.0
	latChange := (float64(radiusKm) / earthRadiusKm) * (180.0 / 3.14159265359)
	lonChange := (float64(radiusKm) / (earthRadiusKm * cos(lat*3.14159265359/180.0))) * (180.0 / 3.14159265359)

	minLat := lat - latChange
	maxLat := lat + latChange
	minLon := lon - lonChange
	maxLon := lon + lonChange

	// Базовый запрос как в Express
	query := `
		SELECT 
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", u.bio,
			u.interests, u."socialLinks", u.age, u.gender, u.role,
			u."lastLatitude", u."lastLongitude", u."lastLocationUpdate",
			u."isProfileVisible", u."isLocationVisible", u."minAge", u."maxAge", u."maxDistance",
			u."fcmToken", u."isOnboardingCompleted", u."createdAt", u."updatedAt"
		FROM "User" u
		WHERE u.id != $1
			AND u."isOnboardingCompleted" = true
			AND u."isProfileVisible" = true
			AND u."lastLatitude" IS NOT NULL
			AND u."lastLongitude" IS NOT NULL
			AND u."lastLatitude" >= $2
			AND u."lastLatitude" <= $3
			AND u."lastLongitude" >= $4
			AND u."lastLongitude" <= $5
			AND ($6::int IS NULL OR u.age >= $6)
			AND ($7::int IS NULL OR u.age <= $7)
		ORDER BY u."lastLocationUpdate" DESC NULLS LAST
		LIMIT $8
	`

	rows, err := r.db.Query(ctx, query,
		userID,
		minLat,
		maxLat,
		minLon,
		maxLon,
		minAge,
		maxAge,
		limit,
	)
	if err != nil {
		logger.Error("Failed to get matches", zap.Error(err))
		return nil, err
	}
	defer rows.Close()

	var users []*model.User
	for rows.Next() {
		var user model.User
		err := rows.Scan(
			&user.ID,
			&user.SupabaseUID,
			&user.Email,
			&user.DisplayName,
			&user.PhotoURL,
			&user.Bio,
			&user.Interests,
			&user.SocialLinks,
			&user.Age,
			&user.Gender,
			&user.Role,
			&user.LastLatitude,
			&user.LastLongitude,
			&user.LastLocationUpdate,
			&user.IsProfileVisible,
			&user.IsLocationVisible,
			&user.MinAge,
			&user.MaxAge,
			&user.MaxDistance,
			&user.FCMToken,
			&user.IsOnboardingCompleted,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			logger.Error("Failed to scan user row", zap.Error(err))
			continue
		}
		users = append(users, &user)
	}

	logger.Info("Found matches", zap.Int("count", len(users)), zap.String("userID", userID))
	return users, nil
}

// cos возвращает косинус угла в радианах
func cos(x float64) float64 {
	return math.Cos(x)
}
