package model

import (
	"time"
)

// UserRole - роль пользователя (соответствует Prisma enum)
type UserRole string

const (
	UserRoleUser      UserRole = "USER"
	UserRoleModerator UserRole = "MODERATOR"
	UserRoleAdmin     UserRole = "ADMIN"
)

// User - модель пользователя (соответствует Prisma схеме)
// Prisma использует camelCase для колонок
type User struct {
	ID                    string     `json:"id"`
	SupabaseUID           string     `json:"supabaseUid"` // Firebase UID (историческое название)
	Email                 string     `json:"email"`
	DisplayName           *string    `json:"displayName,omitempty"`
	PhotoURL              *string    `json:"photoUrl,omitempty"`
	Bio                   *string    `json:"bio,omitempty"`
	Interests             []string   `json:"interests,omitempty"`
	SocialLinks           *string    `json:"socialLinks,omitempty"` // JSONB
	Age                   *int       `json:"age,omitempty"`
	Gender                *string    `json:"gender,omitempty"`
	Role                  UserRole   `json:"role"`
	LastLatitude          *float64   `json:"lastLatitude,omitempty"`
	LastLongitude         *float64   `json:"lastLongitude,omitempty"`
	LastLocationUpdate    *time.Time `json:"lastLocationUpdate,omitempty"`
	IsProfileVisible      bool       `json:"isProfileVisible"`
	IsLocationVisible     bool       `json:"isLocationVisible"`
	MinAge                *int       `json:"minAge,omitempty"`
	MaxAge                *int       `json:"maxAge,omitempty"`
	MaxDistance           int        `json:"maxDistance"`
	FCMToken              *string    `json:"fcmToken,omitempty"`
	IsOnboardingCompleted bool       `json:"isOnboardingCompleted"`
	CreatedAt             time.Time  `json:"createdAt"`
	UpdatedAt             time.Time  `json:"updatedAt"`
}

// CreateUserRequest - запрос на создание пользователя
type CreateUserRequest struct {
	FirebaseUID string  `json:"firebaseUid" validate:"required"`
	Email       string  `json:"email" validate:"required,email"`
	DisplayName *string `json:"displayName,omitempty"`
	PhotoURL    *string `json:"photoUrl,omitempty"`
}

// UpdateUserRequest - запрос на обновление профиля
type UpdateUserRequest struct {
	DisplayName *string  `json:"displayName,omitempty"`
	PhotoURL    *string  `json:"photoUrl,omitempty"`
	Bio         *string  `json:"bio,omitempty"`
	Interests   []string `json:"interests,omitempty"`
	SocialLinks *string  `json:"socialLinks,omitempty"`
	Age         *int     `json:"age,omitempty" validate:"omitempty,min=18,max=100"`
	Gender      *string  `json:"gender,omitempty" validate:"omitempty,gender"`
	MinAge      *int     `json:"minAge,omitempty" validate:"omitempty,min=18,max=100"`
	MaxAge      *int     `json:"maxAge,omitempty" validate:"omitempty,min=18,max=100"`
	MaxDistance *int     `json:"maxDistance,omitempty" validate:"omitempty,min=1000,max=100000"`
	FCMToken    *string  `json:"fcmToken,omitempty"`
}

// UpdateLocationRequest - запрос на обновление геолокации
type UpdateLocationRequest struct {
	Latitude  float64 `json:"latitude" validate:"required,latitude"`
	Longitude float64 `json:"longitude" validate:"required,longitude"`
}

// CompleteOnboardingRequest - завершение онбординга
type CompleteOnboardingRequest struct {
	DisplayName *string  `json:"displayName,omitempty"`
	Bio         *string  `json:"bio,omitempty"`
	Interests   []string `json:"interests,omitempty"`
	Age         *int     `json:"age,omitempty" validate:"omitempty,min=18,max=100"`
	Gender      *string  `json:"gender,omitempty" validate:"omitempty,gender"`
}

// UserResponse - публичный профиль
type UserResponse struct {
	ID                    string    `json:"id"`
	Email                 string    `json:"email"`
	DisplayName           *string   `json:"displayName,omitempty"`
	PhotoURL              *string   `json:"photoUrl,omitempty"`
	Bio                   *string   `json:"bio,omitempty"`
	Interests             []string  `json:"interests,omitempty"`
	Age                   *int      `json:"age,omitempty"`
	Gender                *string   `json:"gender,omitempty"`
	IsOnboardingCompleted bool      `json:"isOnboardingCompleted"`
	CreatedAt             time.Time `json:"createdAt"`
}

// ToResponse конвертирует в публичный профиль
func (u *User) ToResponse() *UserResponse {
	return &UserResponse{
		ID:                    u.ID,
		Email:                 u.Email,
		DisplayName:           u.DisplayName,
		PhotoURL:              u.PhotoURL,
		Bio:                   u.Bio,
		Interests:             u.Interests,
		Age:                   u.Age,
		Gender:                u.Gender,
		IsOnboardingCompleted: u.IsOnboardingCompleted,
		CreatedAt:             u.CreatedAt,
	}
}

// PrivateUserResponse - приватный профиль (для владельца)
type PrivateUserResponse struct {
	UserResponse
	SocialLinks       *string  `json:"socialLinks,omitempty"`
	LastLatitude      *float64 `json:"lastLatitude,omitempty"`
	LastLongitude     *float64 `json:"lastLongitude,omitempty"`
	IsProfileVisible  bool     `json:"isProfileVisible"`
	IsLocationVisible bool     `json:"isLocationVisible"`
	MinAge            *int     `json:"minAge,omitempty"`
	MaxAge            *int     `json:"maxAge,omitempty"`
	MaxDistance       int      `json:"maxDistance"`
	FCMToken          *string  `json:"fcmToken,omitempty"`
}

// ToPrivateResponse конвертирует в приватный профиль
func (u *User) ToPrivateResponse() *PrivateUserResponse {
	return &PrivateUserResponse{
		UserResponse:      *u.ToResponse(),
		SocialLinks:       u.SocialLinks,
		LastLatitude:      u.LastLatitude,
		LastLongitude:     u.LastLongitude,
		IsProfileVisible:  u.IsProfileVisible,
		IsLocationVisible: u.IsLocationVisible,
		MinAge:            u.MinAge,
		MaxAge:            u.MaxAge,
		MaxDistance:       u.MaxDistance,
		FCMToken:          u.FCMToken,
	}
}
