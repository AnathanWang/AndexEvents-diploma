package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/AnathanWang/andexevents/services/users-service/internal/model"
)

// UserRepository интерфейс репозитория пользователей
type UserRepository interface {
	Create(ctx context.Context, supabaseUID, email string, displayName, photoURL *string) (*model.User, error)
	GetByID(ctx context.Context, id string) (*model.User, error)
	GetBySupabaseUID(ctx context.Context, supabaseUID string) (*model.User, error)
	GetByEmail(ctx context.Context, email string) (*model.User, error)
	Update(ctx context.Context, id string, req *model.UpdateUserRequest) (*model.User, error)
	UpdateLocation(ctx context.Context, id string, latitude, longitude float64) error
	GetMatches(ctx context.Context, userID string, latitude, longitude *float64, radiusKm float64, limit int) ([]model.User, error)
	UpdateSupabaseUID(ctx context.Context, id, supabaseUID string) (*model.User, error)
}

type userRepository struct {
	pool *pgxpool.Pool
}

// NewUserRepository создаёт новый репозиторий пользователей
func NewUserRepository(pool *pgxpool.Pool) UserRepository {
	return &userRepository{pool: pool}
}

// Create создаёт нового пользователя
func (r *userRepository) Create(ctx context.Context, supabaseUID, email string, displayName, photoURL *string) (*model.User, error) {
	id := uuid.New().String()
	now := time.Now()

	query := `
		INSERT INTO "User" (
			id, "supabaseUid", email, "displayName", "photoUrl",
			role, "isProfileVisible", "isLocationVisible", "maxDistance",
			"isOnboardingCompleted", "createdAt", "updatedAt"
		) VALUES (
			$1, $2, $3, $4, $5,
			'USER', true, true, 50000,
			false, $6, $6
		)
		RETURNING id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
	`

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, id, supabaseUID, email, displayName, photoURL, now).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// GetByID получает пользователя по ID
func (r *userRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	query := `
		SELECT id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
		FROM "User"
		WHERE id = $1
	`

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// GetBySupabaseUID получает пользователя по Supabase UID
func (r *userRepository) GetBySupabaseUID(ctx context.Context, supabaseUID string) (*model.User, error) {
	query := `
		SELECT id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
		FROM "User"
		WHERE "supabaseUid" = $1
	`

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, supabaseUID).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// GetByEmail получает пользователя по email
func (r *userRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	query := `
		SELECT id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
		FROM "User"
		WHERE email = $1
	`

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// UpdateSupabaseUID обновляет supabaseUid у существующего пользователя
func (r *userRepository) UpdateSupabaseUID(ctx context.Context, id, supabaseUID string) (*model.User, error) {
	query := `
		UPDATE "User"
		SET "supabaseUid" = $1, "updatedAt" = $2
		WHERE id = $3
		RETURNING id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
	`

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, supabaseUID, time.Now(), id).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// Update обновляет профиль пользователя
func (r *userRepository) Update(ctx context.Context, id string, req *model.UpdateUserRequest) (*model.User, error) {
	// Собираем динамический UPDATE запрос
	setClauses := []string{`"updatedAt" = $1`}
	args := []interface{}{time.Now()}
	argNum := 2

	if req.DisplayName != nil {
		setClauses = append(setClauses, fmt.Sprintf(`"displayName" = $%d`, argNum))
		args = append(args, *req.DisplayName)
		argNum++
	}

	if req.PhotoURL != nil {
		setClauses = append(setClauses, fmt.Sprintf(`"photoUrl" = $%d`, argNum))
		args = append(args, *req.PhotoURL)
		argNum++
	}

	if req.Bio != nil {
		setClauses = append(setClauses, fmt.Sprintf(`bio = $%d`, argNum))
		args = append(args, *req.Bio)
		argNum++
	}

	if req.Age != nil {
		setClauses = append(setClauses, fmt.Sprintf(`age = $%d`, argNum))
		args = append(args, *req.Age)
		argNum++
	}

	if req.Gender != nil {
		setClauses = append(setClauses, fmt.Sprintf(`gender = $%d`, argNum))
		args = append(args, *req.Gender)
		argNum++
	}

	if req.Interests != nil {
		setClauses = append(setClauses, fmt.Sprintf(`interests = $%d`, argNum))
		args = append(args, req.Interests)
		argNum++
	}

	if req.SocialLinks != nil {
		setClauses = append(setClauses, fmt.Sprintf(`"socialLinks" = $%d`, argNum))
		args = append(args, req.SocialLinks)
		argNum++
	}

	if req.IsOnboardingCompleted != nil {
		setClauses = append(setClauses, fmt.Sprintf(`"isOnboardingCompleted" = $%d`, argNum))
		args = append(args, *req.IsOnboardingCompleted)
		argNum++
	}

	// Добавляем id в конец
	args = append(args, id)

	query := fmt.Sprintf(`
		UPDATE "User"
		SET %s
		WHERE id = $%d
		RETURNING id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
	`, strings.Join(setClauses, ", "), argNum)

	var user model.User
	var interests []string
	var socialLinks []byte

	err := r.pool.QueryRow(ctx, query, args...).Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = socialLinks
	}

	return &user, nil
}

// UpdateLocation обновляет геолокацию пользователя
func (r *userRepository) UpdateLocation(ctx context.Context, id string, latitude, longitude float64) error {
	query := `
		UPDATE "User"
		SET "lastLatitude" = $1, "lastLongitude" = $2, "lastLocationUpdate" = $3, "updatedAt" = $3
		WHERE id = $4
	`

	now := time.Now()
	_, err := r.pool.Exec(ctx, query, latitude, longitude, now, id)
	return err
}

// GetMatches получает список потенциальных матчей
func (r *userRepository) GetMatches(ctx context.Context, userID string, latitude, longitude *float64, radiusKm float64, limit int) ([]model.User, error) {
	// Получаем текущего пользователя
	currentUser, err := r.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if currentUser == nil {
		return []model.User{}, nil
	}

	// Используем переданные координаты или последние известные
	userLat := latitude
	userLon := longitude
	if userLat == nil {
		userLat = currentUser.LastLatitude
	}
	if userLon == nil {
		userLon = currentUser.LastLongitude
	}

	// Если координаты недоступны, возвращаем пустой список
	if userLat == nil || userLon == nil {
		return []model.User{}, nil
	}

	// Вычисляем границы поиска
	radiusMeters := radiusKm * 1000
	earthRadiusKm := 6371.0
	latChange := (radiusKm / earthRadiusKm) * (180.0 / math.Pi)
	lonChange := (radiusKm / (earthRadiusKm * math.Cos(*userLat*math.Pi/180.0))) * (180.0 / math.Pi)

	minLat := *userLat - latChange
	maxLat := *userLat + latChange
	minLon := *userLon - lonChange
	maxLon := *userLon + lonChange

	query := `
		SELECT id, "supabaseUid", email, "displayName", "photoUrl", bio, interests,
			"socialLinks", age, gender, role, "lastLatitude", "lastLongitude",
			"lastLocationUpdate", "isProfileVisible", "isLocationVisible",
			"minAge", "maxAge", "maxDistance", "fcmToken", "isOnboardingCompleted",
			"createdAt", "updatedAt"
		FROM "User"
		WHERE id != $1
			AND "isOnboardingCompleted" = true
			AND "isProfileVisible" = true
			AND "lastLatitude" IS NOT NULL
			AND "lastLongitude" IS NOT NULL
			AND "lastLatitude" >= $2 AND "lastLatitude" <= $3
			AND "lastLongitude" >= $4 AND "lastLongitude" <= $5
	`

	args := []interface{}{userID, minLat, maxLat, minLon, maxLon}
	argNum := 6

	// Добавляем возрастной фильтр если установлен
	if currentUser.MinAge != nil {
		query += fmt.Sprintf(` AND age >= $%d`, argNum)
		args = append(args, *currentUser.MinAge)
		argNum++
	}
	if currentUser.MaxAge != nil {
		query += fmt.Sprintf(` AND age <= $%d`, argNum)
		args = append(args, *currentUser.MaxAge)
		argNum++
	}

	query += fmt.Sprintf(` LIMIT $%d`, argNum)
	args = append(args, limit)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []model.User
	for rows.Next() {
		var user model.User
		var interests []string
		var socialLinks []byte

		err := rows.Scan(
			&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
			&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
			&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
			&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
			&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
			&user.CreatedAt, &user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		user.Interests = interests
		if socialLinks != nil {
			user.SocialLinks = socialLinks
		}

		// Вычисляем расстояние
		if user.LastLatitude != nil && user.LastLongitude != nil {
			dist := haversineDistance(*userLat, *userLon, *user.LastLatitude, *user.LastLongitude)
			// Фильтруем по точному расстоянию (более точно чем bounding box)
			if dist <= radiusMeters {
				user.Distance = &dist
				users = append(users, user)
			}
		}
	}

	return users, nil
}

// haversineDistance вычисляет расстояние между двумя точками в метрах
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusMeters = 6371000.0

	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLat := (lat2 - lat1) * math.Pi / 180
	deltaLon := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*math.Sin(deltaLon/2)*math.Sin(deltaLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusMeters * c
}

// ScanUser helper для сканирования пользователя
func ScanUser(row pgx.Row) (*model.User, error) {
	var user model.User
	var interests []string
	var socialLinks []byte

	err := row.Scan(
		&user.ID, &user.SupabaseUID, &user.Email, &user.DisplayName, &user.PhotoURL,
		&user.Bio, &interests, &socialLinks, &user.Age, &user.Gender, &user.Role,
		&user.LastLatitude, &user.LastLongitude, &user.LastLocationUpdate,
		&user.IsProfileVisible, &user.IsLocationVisible, &user.MinAge, &user.MaxAge,
		&user.MaxDistance, &user.FCMToken, &user.IsOnboardingCompleted,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	user.Interests = interests
	if socialLinks != nil {
		user.SocialLinks = json.RawMessage(socialLinks)
	}

	return &user, nil
}
