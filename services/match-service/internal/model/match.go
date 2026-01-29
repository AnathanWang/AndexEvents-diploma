package model

import "time"

type MatchAction string

const (
	MatchActionLike      MatchAction = "LIKE"
	MatchActionDislike   MatchAction = "DISLIKE"
	MatchActionSuperLike MatchAction = "SUPER_LIKE"
)

func (a MatchAction) IsValid() bool {
	switch a {
	case MatchActionLike, MatchActionDislike, MatchActionSuperLike:
		return true
	default:
		return false
	}
}

func (a MatchAction) IsLikeType() bool {
	return a == MatchActionLike || a == MatchActionSuperLike
}

type Match struct {
	ID          string       `json:"id"`
	UserAID     string       `json:"userAId"`
	UserBID     string       `json:"userBId"`
	UserAAction *MatchAction `json:"userAAction,omitempty"`
	UserBAction *MatchAction `json:"userBAction,omitempty"`
	IsMutual    bool         `json:"isMutual"`
	MatchedAt   *time.Time   `json:"matchedAt,omitempty"`
	CreatedAt   time.Time    `json:"createdAt"`
	UpdatedAt   time.Time    `json:"updatedAt"`
}

type LikeRequest struct {
	TargetUserID string `json:"targetUserId" binding:"required"`
}

type UsersResponse struct {
	Success bool   `json:"success"`
	Data    []User `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
}

type MatchResponse struct {
	Success bool   `json:"success"`
	Data    *Match `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
}

type ErrorResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
