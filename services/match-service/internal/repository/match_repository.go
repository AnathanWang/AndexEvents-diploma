package repository

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type MatchRepository interface {
	CreateOrUpdateMatch(ctx context.Context, userID, targetUserID string, action model.MatchAction) (*model.Match, error)
	GetMutualMatchUsers(ctx context.Context, userID string) ([]model.User, error)
	GetActionUsers(ctx context.Context, userID string, action model.MatchAction, limit int) ([]model.User, error)
}

type matchRepository struct {
	pool *pgxpool.Pool
}

func NewMatchRepository(pool *pgxpool.Pool) MatchRepository {
	return &matchRepository{pool: pool}
}

func (r *matchRepository) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID string, action model.MatchAction) (*model.Match, error) {
	now := time.Now()

	// Пытаемся найти существующую запись в любом порядке
	selectQuery := `
		SELECT id, "userAId", "userBId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		FROM "Match"
		WHERE ("userAId" = $1 AND "userBId" = $2) OR ("userAId" = $2 AND "userBId" = $1)
		LIMIT 1
	`

	var existing model.Match
	var aAction, bAction *string
	err := r.pool.QueryRow(ctx, selectQuery, userID, targetUserID).Scan(
		&existing.ID,
		&existing.UserAID,
		&existing.UserBID,
		&aAction,
		&bAction,
		&existing.IsMutual,
		&existing.MatchedAt,
		&existing.CreatedAt,
		&existing.UpdatedAt,
	)

	if err != nil && err != pgx.ErrNoRows {
		return nil, err
	}

	// Нет записи -> создаём
	if err == pgx.ErrNoRows {
		insertQuery := `
			INSERT INTO "Match" (
				id, "userAId", "userBId", "userAAction", "isMutual", "createdAt", "updatedAt"
			) VALUES (
				$1, $2, $3, $4, false, $5, $5
			)
			RETURNING id, "userAId", "userBId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		`
		id := uuid.New().String()
		actionStr := string(action)

		var created model.Match
		var ca, cb *string
		err := r.pool.QueryRow(ctx, insertQuery, id, userID, targetUserID, actionStr, now).Scan(
			&created.ID,
			&created.UserAID,
			&created.UserBID,
			&ca,
			&cb,
			&created.IsMutual,
			&created.MatchedAt,
			&created.CreatedAt,
			&created.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		if ca != nil {
			a := model.MatchAction(*ca)
			created.UserAAction = &a
		}
		if cb != nil {
			b := model.MatchAction(*cb)
			created.UserBAction = &b
		}
		return &created, nil
	}

	if aAction != nil {
		a := model.MatchAction(*aAction)
		existing.UserAAction = &a
	}
	if bAction != nil {
		b := model.MatchAction(*bAction)
		existing.UserBAction = &b
	}

	// Обновляем действие для текущего пользователя
	var otherAction *model.MatchAction
	setColumn := "userAAction"
	if existing.UserAID == userID {
		otherAction = existing.UserBAction
		setColumn = "userAAction"
	} else {
		otherAction = existing.UserAAction
		setColumn = "userBAction"
	}

	isMutual := false
	if otherAction != nil {
		isMutual = otherAction.IsLikeType() && action.IsLikeType()
	}

	var matchedAt interface{} = nil
	if isMutual {
		matchedAt = now
	}

	updateQuery := `
		UPDATE "Match"
		SET ` + setColumn + ` = $1, "isMutual" = $2, "matchedAt" = $3, "updatedAt" = $4
		WHERE id = $5
		RETURNING id, "userAId", "userBId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
	`

	actionStr := string(action)
	var updated model.Match
	var ua, ub *string
	err = r.pool.QueryRow(ctx, updateQuery, actionStr, isMutual, matchedAt, now, existing.ID).Scan(
		&updated.ID,
		&updated.UserAID,
		&updated.UserBID,
		&ua,
		&ub,
		&updated.IsMutual,
		&updated.MatchedAt,
		&updated.CreatedAt,
		&updated.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if ua != nil {
		a := model.MatchAction(*ua)
		updated.UserAAction = &a
	}
	if ub != nil {
		b := model.MatchAction(*ub)
		updated.UserBAction = &b
	}

	return &updated, nil
}

func scanUser(row pgx.Row, dest *model.User) error {
	var interests []string
	var socialLinks []byte

	err := row.Scan(
		&dest.ID,
		&dest.SupabaseUID,
		&dest.Email,
		&dest.DisplayName,
		&dest.PhotoURL,
		&dest.Bio,
		&interests,
		&socialLinks,
		&dest.Age,
		&dest.Gender,
		&dest.Role,
		&dest.LastLatitude,
		&dest.LastLongitude,
		&dest.LastLocationUpdate,
		&dest.IsProfileVisible,
		&dest.IsLocationVisible,
		&dest.MinAge,
		&dest.MaxAge,
		&dest.MaxDistance,
		&dest.FCMToken,
		&dest.IsOnboardingCompleted,
		&dest.CreatedAt,
		&dest.UpdatedAt,
	)
	if err != nil {
		return err
	}

	dest.Interests = interests
	if socialLinks != nil {
		dest.SocialLinks = json.RawMessage(socialLinks)
	}

	return nil
}

func (r *matchRepository) GetMutualMatchUsers(ctx context.Context, userID string) ([]model.User, error) {
	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN "User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE m."isMutual" = true AND (m."userAId" = $1 OR m."userBId" = $1)
		ORDER BY m."matchedAt" DESC NULLS LAST, m."updatedAt" DESC
	`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]model.User, 0)
	for rows.Next() {
		var u model.User
		if err := scanUser(rows, &u); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

func (r *matchRepository) GetActionUsers(ctx context.Context, userID string, action model.MatchAction, limit int) ([]model.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	query := `
		WITH recent AS (
			SELECT *
			FROM "Match"
			WHERE "userAId" = $1 OR "userBId" = $1
			ORDER BY "createdAt" DESC
			LIMIT $2
		)
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM recent m
		JOIN "User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE (CASE WHEN m."userAId" = $1 THEN m."userAAction" ELSE m."userBAction" END) = $3
		ORDER BY m."createdAt" DESC
	`

	rows, err := r.pool.Query(ctx, query, userID, limit, string(action))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]model.User, 0)
	for rows.Next() {
		var u model.User
		if err := scanUser(rows, &u); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}
