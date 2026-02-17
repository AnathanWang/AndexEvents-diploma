package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/AnathanWang/andexevents/services/events-service/internal/model"
)

// ParticipantRepository интерфейс для работы с участниками событий
type ParticipantRepository interface {
	AddParticipant(ctx context.Context, participant *model.Participant) error
	RemoveParticipant(ctx context.Context, eventID, userID string) error
	GetParticipants(ctx context.Context, eventID string, page, pageSize int) ([]model.ParticipantWithUser, int, error)
	GetParticipation(ctx context.Context, eventID, userID string) (*model.Participant, error)
	GetParticipantCount(ctx context.Context, eventID string) (int, error)
	UpdateStatus(ctx context.Context, eventID, userID string, status model.ParticipantStatus) error
}

type participantRepository struct {
	pool *pgxpool.Pool
}

// NewParticipantRepository создаёт новый репозиторий участников
func NewParticipantRepository(pool *pgxpool.Pool) ParticipantRepository {
	return &participantRepository{pool: pool}
}

// AddParticipant добавляет участника в событие (upsert)
func (r *participantRepository) AddParticipant(ctx context.Context, participant *model.Participant) error {
	query := `
		INSERT INTO "Participant" ("eventId", "userId", status, "joinedAt")
		VALUES ($1, $2, $3, $4)
		ON CONFLICT ("eventId", "userId")
		DO UPDATE SET status = $3, "joinedAt" = $4
		RETURNING "joinedAt"
	`

	err := r.pool.QueryRow(ctx, query,
		participant.EventID,
		participant.UserID,
		participant.Status,
		time.Now(),
	).Scan(&participant.JoinedAt)

	return err
}

// RemoveParticipant удаляет участника из события
func (r *participantRepository) RemoveParticipant(ctx context.Context, eventID, userID string) error {
	query := `DELETE FROM "Participant" WHERE "eventId" = $1 AND "userId" = $2`
	result, err := r.pool.Exec(ctx, query, eventID, userID)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

// GetParticipants получает список участников события с пагинацией
func (r *participantRepository) GetParticipants(ctx context.Context, eventID string, page, pageSize int) ([]model.ParticipantWithUser, int, error) {
	countQuery := `SELECT COUNT(*) FROM "Participant" WHERE "eventId" = $1`
	var total int
	err := r.pool.QueryRow(ctx, countQuery, eventID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	selectQuery := `
		SELECT 
			p."eventId", p."userId", p.status, p."joinedAt",
			u.name, u.email, u."photoURL"
		FROM "Participant" p
		JOIN "User" u ON u.id = p."userId"
		WHERE p."eventId" = $1
		ORDER BY p."joinedAt" DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, selectQuery, eventID, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var participants []model.ParticipantWithUser
	for rows.Next() {
		var p model.ParticipantWithUser
		err := rows.Scan(
			&p.EventID, &p.UserID, &p.Status, &p.JoinedAt,
			&p.Name, &p.Email, &p.PhotoURL,
		)
		if err != nil {
			return nil, 0, err
		}
		participants = append(participants, p)
	}

	return participants, total, nil
}

// GetParticipation проверяет участие пользователя в событии
func (r *participantRepository) GetParticipation(ctx context.Context, eventID, userID string) (*model.Participant, error) {
	query := `
		SELECT "eventId", "userId", status, "joinedAt"
		FROM "Participant"
		WHERE "eventId" = $1 AND "userId" = $2
	`

	var participant model.Participant
	err := r.pool.QueryRow(ctx, query, eventID, userID).Scan(
		&participant.EventID, &participant.UserID, &participant.Status, &participant.JoinedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &participant, nil
}

// GetParticipantCount получает количество участников события
func (r *participantRepository) GetParticipantCount(ctx context.Context, eventID string) (int, error) {
	query := `SELECT COUNT(*) FROM "Participant" WHERE "eventId" = $1`
	var count int
	err := r.pool.QueryRow(ctx, query, eventID).Scan(&count)
	return count, err
}

// UpdateStatus обновляет статус участника
func (r *participantRepository) UpdateStatus(ctx context.Context, eventID, userID string, status model.ParticipantStatus) error {
	query := `
		UPDATE "Participant"
		SET status = $3
		WHERE "eventId" = $1 AND "userId" = $2
	`
	result, err := r.pool.Exec(ctx, query, eventID, userID, status)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}
