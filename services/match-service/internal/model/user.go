package model

import (
	"encoding/json"
	"time"
)

type UserRole string

const (
	UserRoleUser      UserRole = "USER"
	UserRoleModerator UserRole = "MODERATOR"
	UserRoleAdmin     UserRole = "ADMIN"
)

type User struct {
	ID                    string          `json:"id"`
	SupabaseUID           string          `json:"supabaseUid"`
	Email                 string          `json:"email"`
	DisplayName           *string         `json:"displayName,omitempty"`
	PhotoURL              *string         `json:"photoUrl,omitempty"`
	Bio                   *string         `json:"bio,omitempty"`
	Interests             []string        `json:"interests,omitempty"`
	SocialLinks           json.RawMessage `json:"socialLinks,omitempty"`
	Age                   *int            `json:"age,omitempty"`
	Gender                *string         `json:"gender,omitempty"`
	Role                  UserRole        `json:"role"`
	LastLatitude          *float64        `json:"lastLatitude,omitempty"`
	LastLongitude         *float64        `json:"lastLongitude,omitempty"`
	LastLocationUpdate    *time.Time      `json:"lastLocationUpdate,omitempty"`
	IsProfileVisible      bool            `json:"isProfileVisible"`
	IsLocationVisible     bool            `json:"isLocationVisible"`
	MinAge                *int            `json:"minAge,omitempty"`
	MaxAge                *int            `json:"maxAge,omitempty"`
	MaxDistance           int             `json:"maxDistance"`
	FCMToken              *string         `json:"fcmToken,omitempty"`
	IsOnboardingCompleted bool            `json:"isOnboardingCompleted"`
	CreatedAt             time.Time       `json:"createdAt"`
	UpdatedAt             time.Time       `json:"updatedAt"`
}
