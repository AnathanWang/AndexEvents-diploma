package model

import (
	"time"
)

// EventStatus определяет статус события
type EventStatus string

const (
	EventStatusPending  EventStatus = "PENDING"
	EventStatusApproved EventStatus = "APPROVED"
	EventStatusRejected EventStatus = "REJECTED"
)

// ParticipantStatus определяет статус участия
type ParticipantStatus string

const (
	ParticipantStatusInterested ParticipantStatus = "INTERESTED"
	ParticipantStatusGoing      ParticipantStatus = "GOING"
)

// Event представляет событие в системе
type Event struct {
	ID                string        `json:"id" db:"id"`
	Title             string        `json:"title" db:"title"`
	Description       *string       `json:"description,omitempty" db:"description"`
	Category          string        `json:"category" db:"category"`
	Location          *string       `json:"location,omitempty" db:"location"`
	Latitude          *float64      `json:"latitude,omitempty" db:"latitude"`
	Longitude         *float64      `json:"longitude,omitempty" db:"longitude"`
	DateTime          time.Time     `json:"dateTime" db:"date_time"`
	EndDateTime       *time.Time    `json:"endDateTime,omitempty" db:"end_date_time"`
	Price             *float64      `json:"price,omitempty" db:"price"`
	ImageURL          *string       `json:"imageUrl,omitempty" db:"image_url"`
	IsOnline          bool          `json:"isOnline" db:"is_online"`
	Status            EventStatus   `json:"status" db:"status"`
	MaxParticipants   *int          `json:"maxParticipants,omitempty" db:"max_participants"`
	MinAge            *int          `json:"minAge,omitempty" db:"min_age"`
	MaxAge            *int          `json:"maxAge,omitempty" db:"max_age"`
	CreatedByID       string        `json:"createdById" db:"created_by_id"`
	CreatedAt         time.Time     `json:"createdAt" db:"created_at"`
	UpdatedAt         time.Time     `json:"updatedAt" db:"updated_at"`
	Creator           *EventCreator `json:"creator,omitempty"`
	ParticipantsCount int           `json:"participantsCount,omitempty"`
	Distance          *float64      `json:"distance,omitempty"`
}

// EventCreator содержит информацию о создателе события
type EventCreator struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Email    string  `json:"email"`
	PhotoURL *string `json:"photoUrl,omitempty"`
}

// Participant представляет участника события
type Participant struct {
	ID        string            `json:"id" db:"id"`
	EventID   string            `json:"eventId" db:"event_id"`
	UserID    string            `json:"userId" db:"user_id"`
	Status    ParticipantStatus `json:"status" db:"status"`
	JoinedAt  time.Time         `json:"joinedAt" db:"joined_at"`
	CreatedAt time.Time         `json:"createdAt" db:"created_at"`
	UpdatedAt time.Time         `json:"updatedAt" db:"updated_at"`
	User      *ParticipantUser  `json:"user,omitempty"`
}

// ParticipantWithUser участник с информацией о пользователе (для JOIN запросов)
type ParticipantWithUser struct {
	EventID  string            `json:"eventId"`
	UserID   string            `json:"userId"`
	Status   ParticipantStatus `json:"status"`
	JoinedAt time.Time         `json:"joinedAt"`
	Name     string            `json:"name"`
	Email    string            `json:"email"`
	PhotoURL *string           `json:"photoUrl,omitempty"`
}

// ParticipantUser содержит информацию о пользователе-участнике
type ParticipantUser struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Email    string  `json:"email"`
	PhotoURL *string `json:"photoUrl,omitempty"`
}

// CreateEventRequest запрос на создание события
type CreateEventRequest struct {
	Title           string      `json:"title" binding:"required,min=3,max=200"`
	Description     *string     `json:"description,omitempty"`
	Category        string      `json:"category" binding:"required"`
	Location        *string     `json:"location,omitempty"`
	Latitude        *float64    `json:"latitude,omitempty"`
	Longitude       *float64    `json:"longitude,omitempty"`
	DateTime        time.Time   `json:"dateTime" binding:"required"`
	EndDateTime     *time.Time  `json:"endDateTime,omitempty"`
	Price           *float64    `json:"price,omitempty"`
	ImageURL        *string     `json:"imageUrl,omitempty"`
	IsOnline        bool        `json:"isOnline"`
	MaxParticipants *int        `json:"maxParticipants,omitempty"`
	MinAge          *int        `json:"minAge,omitempty"`
	MaxAge          *int        `json:"maxAge,omitempty"`
	Status          EventStatus `json:"status,omitempty"`
}

// UpdateEventRequest запрос на обновление события
type UpdateEventRequest struct {
	Title           *string      `json:"title,omitempty"`
	Description     *string      `json:"description,omitempty"`
	Category        *string      `json:"category,omitempty"`
	Location        *string      `json:"location,omitempty"`
	Latitude        *float64     `json:"latitude,omitempty"`
	Longitude       *float64     `json:"longitude,omitempty"`
	DateTime        *time.Time   `json:"dateTime,omitempty"`
	EndDateTime     *time.Time   `json:"endDateTime,omitempty"`
	Price           *float64     `json:"price,omitempty"`
	ImageURL        *string      `json:"imageUrl,omitempty"`
	IsOnline        *bool        `json:"isOnline,omitempty"`
	Status          *EventStatus `json:"status,omitempty"`
	MaxParticipants *int         `json:"maxParticipants,omitempty"`
	MinAge          *int         `json:"minAge,omitempty"`
	MaxAge          *int         `json:"maxAge,omitempty"`
}

// GetEventsRequest параметры запроса списка событий
type GetEventsRequest struct {
	Page      int          `form:"page,default=1"`
	PageSize  int          `form:"pageSize,default=20"`
	Category  string       `form:"category"`
	Status    *EventStatus `form:"status"`
	IsOnline  *bool        `form:"isOnline"`
	Latitude  *float64     `form:"latitude"`
	Longitude *float64     `form:"longitude"`
	Radius    *float64     `form:"radius"`
	Search    string       `form:"search"`
	SortBy    string       `form:"sortBy,default=dateTime"`
	SortOrder string       `form:"sortOrder,default=asc"`
}

// ParticipateRequest запрос на участие в событии
type ParticipateRequest struct {
	Status ParticipantStatus `json:"status" binding:"required,oneof=INTERESTED GOING"`
}

// EventsResponse ответ со списком событий
type EventsResponse struct {
	Events     []Event `json:"events"`
	Total      int     `json:"total"`
	Page       int     `json:"page"`
	PageSize   int     `json:"pageSize"`
	TotalPages int     `json:"totalPages"`
}

// PaginatedEventsResponse ответ со списком событий с пагинацией
type PaginatedEventsResponse struct {
	Events     []Event `json:"events"`
	Total      int     `json:"total"`
	Page       int     `json:"page"`
	PageSize   int     `json:"pageSize"`
	TotalPages int     `json:"totalPages"`
}

// EventResponse ответ с событием и дополнительной информацией
type EventResponse struct {
	Event            Event         `json:"event"`
	ParticipantCount int           `json:"participantCount"`
	Creator          *EventCreator `json:"creator,omitempty"`
}

// ParticipantsResponse ответ со списком участников
type ParticipantsResponse struct {
	Participants []ParticipantWithUser `json:"participants"`
	Total        int                   `json:"total"`
	Page         int                   `json:"page"`
	PageSize     int                   `json:"pageSize"`
	TotalPages   int                   `json:"totalPages"`
}
