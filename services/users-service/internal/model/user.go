package model

import (
	"encoding/json"
	"time"
)

// UserRole определяет роль пользователя
type UserRole string

const (
	UserRoleUser      UserRole = "USER"
	UserRoleModerator UserRole = "MODERATOR"
	UserRoleAdmin     UserRole = "ADMIN"
)

// User представляет пользователя в системе
type User struct {
	ID                    string          `json:"id" db:"id"`
	SupabaseUID           string          `json:"supabaseUid" db:"supabase_uid"`
	Email                 string          `json:"email" db:"email"`
	DisplayName           *string         `json:"displayName,omitempty" db:"display_name"`
	PhotoURL              *string         `json:"photoUrl,omitempty" db:"photo_url"`
	Bio                   *string         `json:"bio,omitempty" db:"bio"`
	Interests             []string        `json:"interests,omitempty" db:"interests"`
	SocialLinks           json.RawMessage `json:"socialLinks,omitempty" db:"social_links"`
	Age                   *int            `json:"age,omitempty" db:"age"`
	Gender                *string         `json:"gender,omitempty" db:"gender"`
	Role                  UserRole        `json:"role" db:"role"`
	LastLatitude          *float64        `json:"lastLatitude,omitempty" db:"last_latitude"`
	LastLongitude         *float64        `json:"lastLongitude,omitempty" db:"last_longitude"`
	LastLocationUpdate    *time.Time      `json:"lastLocationUpdate,omitempty" db:"last_location_update"`
	IsProfileVisible      bool            `json:"isProfileVisible" db:"is_profile_visible"`
	IsLocationVisible     bool            `json:"isLocationVisible" db:"is_location_visible"`
	MinAge                *int            `json:"minAge,omitempty" db:"min_age"`
	MaxAge                *int            `json:"maxAge,omitempty" db:"max_age"`
	MaxDistance           int             `json:"maxDistance" db:"max_distance"`
	FCMToken              *string         `json:"fcmToken,omitempty" db:"fcm_token"`
	IsOnboardingCompleted bool            `json:"isOnboardingCompleted" db:"is_onboarding_completed"`
	CreatedAt             time.Time       `json:"createdAt" db:"created_at"`
	UpdatedAt             time.Time       `json:"updatedAt" db:"updated_at"`
	// Поле для расстояния (вычисляемое, не хранится в БД)
	Distance *float64 `json:"distance,omitempty"`
}

// CreateUserRequest запрос на создание пользователя
type CreateUserRequest struct {
	DisplayName *string `json:"displayName,omitempty"`
	PhotoURL    *string `json:"photoUrl,omitempty"`
}

// UpdateUserRequest запрос на обновление профиля
type UpdateUserRequest struct {
	DisplayName           *string         `json:"displayName,omitempty"`
	PhotoURL              *string         `json:"photoUrl,omitempty"`
	Bio                   *string         `json:"bio,omitempty"`
	Age                   *int            `json:"age,omitempty"`
	Gender                *string         `json:"gender,omitempty"`
	Interests             []string        `json:"interests,omitempty"`
	SocialLinks           json.RawMessage `json:"socialLinks,omitempty"`
	IsOnboardingCompleted *bool           `json:"isOnboardingCompleted,omitempty"`
}

// UpdateLocationRequest запрос на обновление локации
type UpdateLocationRequest struct {
	Latitude  float64 `json:"latitude" binding:"required,min=-90,max=90"`
	Longitude float64 `json:"longitude" binding:"required,min=-180,max=180"`
}

// GetMatchesRequest параметры поиска матчей
type GetMatchesRequest struct {
	Latitude  *float64 `form:"latitude"`
	Longitude *float64 `form:"longitude"`
	RadiusKm  float64  `form:"radiusKm,default=50"`
	Limit     int      `form:"limit,default=20"`
}

// UserResponse ответ с данными пользователя
type UserResponse struct {
	Success bool   `json:"success"`
	Data    *User  `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
}

// UsersResponse ответ со списком пользователей
type UsersResponse struct {
	Success bool   `json:"success"`
	Data    []User `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
}

// ErrorResponse ответ с ошибкой
type ErrorResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
