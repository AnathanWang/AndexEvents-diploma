package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
)

// EventRepository интерфейс репозитория событий
type EventRepository interface {
	Create(ctx context.Context, event *model.Event) error
	GetByID(ctx context.Context, id string) (*model.Event, error)
	GetAll(ctx context.Context, req *model.GetEventsRequest) ([]model.Event, int, error)
	GetByUserID(ctx context.Context, userID string, page, pageSize int) ([]model.Event, int, error)
	Update(ctx context.Context, id string, req *model.UpdateEventRequest) (*model.Event, error)
	Delete(ctx context.Context, id string) error
	GetNearby(ctx context.Context, lat, lon, radius float64, page, pageSize int) ([]model.Event, int, error)
	GetCreatorByEventID(ctx context.Context, eventID string) (*model.EventCreator, error)
}

type eventRepository struct {
	pool *pgxpool.Pool
}

// NewEventRepository создаёт новый репозиторий событий
func NewEventRepository(pool *pgxpool.Pool) EventRepository {
	return &eventRepository{pool: pool}
}

// Create создаёт новое событие
func (r *eventRepository) Create(ctx context.Context, event *model.Event) error {
	query := `
		INSERT INTO "Event" (
			id, title, description, category, location, latitude, longitude,
			"locationGeo", "dateTime", "endDateTime", price, "imageUrl", "isOnline",
			status, "maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt"
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7,
			CASE WHEN $6 IS NOT NULL AND $7 IS NOT NULL 
				THEN ST_SetSRID(ST_MakePoint($7, $6), 4326)::geography 
				ELSE NULL 
			END,
			$8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $18
		)
		RETURNING "createdAt", "updatedAt"
	`

	err := r.pool.QueryRow(ctx, query,
		event.ID,
		event.Title,
		event.Description,
		event.Category,
		event.Location,
		event.Latitude,
		event.Longitude,
		event.DateTime,
		event.EndDateTime,
		event.Price,
		event.ImageURL,
		event.IsOnline,
		event.Status,
		event.MaxParticipants,
		event.MinAge,
		event.MaxAge,
		event.CreatedByID,
		time.Now(),
	).Scan(&event.CreatedAt, &event.UpdatedAt)

	return err
}

// GetByID получает событие по ID
func (r *eventRepository) GetByID(ctx context.Context, id string) (*model.Event, error) {
	query := `
		SELECT 
			id, title, description, category, location, latitude, longitude,
			"dateTime", "endDateTime", price, "imageUrl", "isOnline", status,
			"maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt"
		FROM "Event"
		WHERE id = $1
	`

	var event model.Event
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&event.ID, &event.Title, &event.Description, &event.Category,
		&event.Location, &event.Latitude, &event.Longitude,
		&event.DateTime, &event.EndDateTime, &event.Price, &event.ImageURL,
		&event.IsOnline, &event.Status, &event.MaxParticipants,
		&event.MinAge, &event.MaxAge, &event.CreatedByID,
		&event.CreatedAt, &event.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &event, nil
}

// GetAll получает список событий с фильтрацией и пагинацией
func (r *eventRepository) GetAll(ctx context.Context, req *model.GetEventsRequest) ([]model.Event, int, error) {
	baseQuery := `FROM "Event" WHERE 1=1`
	countQuery := `SELECT COUNT(*) ` + baseQuery

	var conditions []string
	var args []interface{}
	argNum := 1

	if req.Category != "" {
		conditions = append(conditions, fmt.Sprintf("category = $%d", argNum))
		args = append(args, req.Category)
		argNum++
	}

	if req.Status != nil {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argNum))
		args = append(args, *req.Status)
		argNum++
	}

	if req.IsOnline != nil {
		conditions = append(conditions, fmt.Sprintf(`"isOnline" = $%d`, argNum))
		args = append(args, *req.IsOnline)
		argNum++
	}

	if req.Search != "" {
		conditions = append(conditions, fmt.Sprintf("(title ILIKE $%d OR description ILIKE $%d)", argNum, argNum))
		args = append(args, "%"+req.Search+"%")
		argNum++
	}

	if len(conditions) > 0 {
		condStr := " AND " + strings.Join(conditions, " AND ")
		baseQuery += condStr
		countQuery += condStr
	}

	var total int
	err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	orderBy := `"dateTime"`
	switch req.SortBy {
	case "createdAt":
		orderBy = `"createdAt"`
	case "title":
		orderBy = "title"
	}

	orderDir := "ASC"
	if strings.ToLower(req.SortOrder) == "desc" {
		orderDir = "DESC"
	}

	offset := (req.Page - 1) * req.PageSize

	selectQuery := fmt.Sprintf(`
		SELECT 
			id, title, description, category, location, latitude, longitude,
			"dateTime", "endDateTime", price, "imageUrl", "isOnline", status,
			"maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt"
		%s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, baseQuery, orderBy, orderDir, argNum, argNum+1)

	args = append(args, req.PageSize, offset)

	rows, err := r.pool.Query(ctx, selectQuery, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []model.Event
	for rows.Next() {
		var event model.Event
		err := rows.Scan(
			&event.ID, &event.Title, &event.Description, &event.Category,
			&event.Location, &event.Latitude, &event.Longitude,
			&event.DateTime, &event.EndDateTime, &event.Price, &event.ImageURL,
			&event.IsOnline, &event.Status, &event.MaxParticipants,
			&event.MinAge, &event.MaxAge, &event.CreatedByID,
			&event.CreatedAt, &event.UpdatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		events = append(events, event)
	}

	return events, total, nil
}

// GetNearby получает события поблизости с использованием PostGIS
func (r *eventRepository) GetNearby(ctx context.Context, lat, lon, radius float64, page, pageSize int) ([]model.Event, int, error) {
	pointQuery := `ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography`

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM "Event"
		WHERE "locationGeo" IS NOT NULL
		AND ST_DWithin("locationGeo", %s, $3)
	`, pointQuery)

	var total int
	err := r.pool.QueryRow(ctx, countQuery, lon, lat, radius).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	selectQuery := fmt.Sprintf(`
		SELECT 
			id, title, description, category, location, latitude, longitude,
			"dateTime", "endDateTime", price, "imageUrl", "isOnline", status,
			"maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt",
			ST_Distance("locationGeo", %s) as distance
		FROM "Event"
		WHERE "locationGeo" IS NOT NULL
		AND ST_DWithin("locationGeo", %s, $3)
		ORDER BY distance ASC
		LIMIT $4 OFFSET $5
	`, pointQuery, pointQuery)

	rows, err := r.pool.Query(ctx, selectQuery, lon, lat, radius, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []model.Event
	for rows.Next() {
		var event model.Event
		var distance float64
		err := rows.Scan(
			&event.ID, &event.Title, &event.Description, &event.Category,
			&event.Location, &event.Latitude, &event.Longitude,
			&event.DateTime, &event.EndDateTime, &event.Price, &event.ImageURL,
			&event.IsOnline, &event.Status, &event.MaxParticipants,
			&event.MinAge, &event.MaxAge, &event.CreatedByID,
			&event.CreatedAt, &event.UpdatedAt, &distance,
		)
		if err != nil {
			return nil, 0, err
		}
		event.Distance = &distance
		events = append(events, event)
	}

	return events, total, nil
}

// GetByUserID получает события созданные пользователем
func (r *eventRepository) GetByUserID(ctx context.Context, userID string, page, pageSize int) ([]model.Event, int, error) {
	countQuery := `SELECT COUNT(*) FROM "Event" WHERE "createdById" = $1`
	var total int
	err := r.pool.QueryRow(ctx, countQuery, userID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	selectQuery := `
		SELECT 
			id, title, description, category, location, latitude, longitude,
			"dateTime", "endDateTime", price, "imageUrl", "isOnline", status,
			"maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt"
		FROM "Event"
		WHERE "createdById" = $1
		ORDER BY "createdAt" DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, selectQuery, userID, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []model.Event
	for rows.Next() {
		var event model.Event
		err := rows.Scan(
			&event.ID, &event.Title, &event.Description, &event.Category,
			&event.Location, &event.Latitude, &event.Longitude,
			&event.DateTime, &event.EndDateTime, &event.Price, &event.ImageURL,
			&event.IsOnline, &event.Status, &event.MaxParticipants,
			&event.MinAge, &event.MaxAge, &event.CreatedByID,
			&event.CreatedAt, &event.UpdatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		events = append(events, event)
	}

	return events, total, nil
}

// Update обновляет событие
func (r *eventRepository) Update(ctx context.Context, id string, req *model.UpdateEventRequest) (*model.Event, error) {
	var setClauses []string
	var args []interface{}
	argNum := 1

	if req.Title != nil {
		setClauses = append(setClauses, fmt.Sprintf("title = $%d", argNum))
		args = append(args, *req.Title)
		argNum++
	}
	if req.Description != nil {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argNum))
		args = append(args, *req.Description)
		argNum++
	}
	if req.Category != nil {
		setClauses = append(setClauses, fmt.Sprintf("category = $%d", argNum))
		args = append(args, *req.Category)
		argNum++
	}

	if len(setClauses) == 0 {
		return r.GetByID(ctx, id)
	}

	setClauses = append(setClauses, fmt.Sprintf(`"updatedAt" = $%d`, argNum))
	args = append(args, time.Now())
	argNum++

	args = append(args, id)

	query := fmt.Sprintf(`
		UPDATE "Event"
		SET %s
		WHERE id = $%d
		RETURNING id, title, description, category, location, latitude, longitude,
			"dateTime", "endDateTime", price, "imageUrl", "isOnline", status,
			"maxParticipants", "minAge", "maxAge", "createdById", "createdAt", "updatedAt"
	`, strings.Join(setClauses, ", "), argNum)

	var event model.Event
	err := r.pool.QueryRow(ctx, query, args...).Scan(
		&event.ID, &event.Title, &event.Description, &event.Category,
		&event.Location, &event.Latitude, &event.Longitude,
		&event.DateTime, &event.EndDateTime, &event.Price, &event.ImageURL,
		&event.IsOnline, &event.Status, &event.MaxParticipants,
		&event.MinAge, &event.MaxAge, &event.CreatedByID,
		&event.CreatedAt, &event.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &event, nil
}

// Delete удаляет событие
func (r *eventRepository) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM "Event" WHERE id = $1`
	result, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

// GetCreatorByEventID получает информацию о создателе события
func (r *eventRepository) GetCreatorByEventID(ctx context.Context, eventID string) (*model.EventCreator, error) {
	query := `
		SELECT u.id, u.name, u.email, u."photoURL"
		FROM "User" u
		JOIN "Event" e ON e."createdById" = u.id
		WHERE e.id = $1
	`

	var creator model.EventCreator
	err := r.pool.QueryRow(ctx, query, eventID).Scan(
		&creator.ID, &creator.Name, &creator.Email, &creator.PhotoURL,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &creator, nil
}
