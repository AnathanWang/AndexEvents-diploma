package repository

import (
	"context"
	"encoding/json"
	"time"

	"database/sql"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type MatchRepository interface {
	CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error)
	GetMutualMatchUsers(ctx context.Context, userID, eventID string) ([]model.User, error)
	GetActionUsers(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error)
	GetIncomingLikeUsers(ctx context.Context, userID, eventID string, limit int) ([]model.User, error)
	GetUserByID(ctx context.Context, userID string) (model.User, error)
}

type PgxPoolIface interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type matchRepository struct {
	pool PgxPoolIface
}

func NewMatchRepository(pool PgxPoolIface) MatchRepository {
	return &matchRepository{pool: pool}
}

func (r *matchRepository) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error) {
	now := time.Now()

	// Пытаемся найти существующую запись в любом порядке
	selectQuery := `
		SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		FROM "Match"
		WHERE (("userAId" = $1 AND "userBId" = $2) OR ("userAId" = $2 AND "userBId" = $1)) 
		  AND COALESCE("eventId", '') = COALESCE($3, '')
		LIMIT 1
	`

	var existing model.Match
	var existingEventID sql.NullString
	var aAction, bAction *string
	err := r.pool.QueryRow(ctx, selectQuery, userID, targetUserID, eventID).Scan(
		&existing.ID,
		&existing.UserAID,
		&existing.UserBID,
		&existingEventID,
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
				id, "userAId", "userBId", "eventId", "userAAction", "isMutual", "createdAt", "updatedAt"
			) VALUES (
				$1, $2, $3, NULLIF($4, ''), $5, false, $6, $6
			)
			RETURNING id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
		`
		id := uuid.New().String()
		actionStr := string(action)

		var created model.Match
		var createdEventID sql.NullString
		var ca, cb *string
		err := r.pool.QueryRow(ctx, insertQuery, id, userID, targetUserID, eventID, actionStr, now).Scan(
			&created.ID,
			&created.UserAID,
			&created.UserBID,
			&createdEventID,
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
		if createdEventID.Valid {
			created.EventID = createdEventID.String
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
	if existingEventID.Valid {
		existing.EventID = existingEventID.String
	}

	// Обновляем действие для текущего пользователя
	var otherAction *model.MatchAction
	setColumn := `"userAAction"`
	if existing.UserAID == userID {
		otherAction = existing.UserBAction
		setColumn = `"userAAction"`
	} else {
		otherAction = existing.UserAAction
		setColumn = `"userBAction"`
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
		RETURNING id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"
	`

	actionStr := string(action)
	var updated model.Match
	var updatedEventID sql.NullString
	var ua, ub *string
	err = r.pool.QueryRow(ctx, updateQuery, actionStr, isMutual, matchedAt, now, existing.ID).Scan(
		&updated.ID,
		&updated.UserAID,
		&updated.UserBID,
		&updatedEventID,
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
	if updatedEventID.Valid {
		updated.EventID = updatedEventID.String
	}

	return &updated, nil
}

func scanUser(row pgx.Row, dest *model.User) error {
	var interests []string
	var photos []string
	var socialLinks []byte

	err := row.Scan(
		&dest.ID,
		&dest.SupabaseUID,
		&dest.Email,
		&dest.DisplayName,
		&dest.PhotoURL,
		&photos,
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
		&dest.ShowVisitedEvents,
		&dest.ShowInMatches,
		&dest.IncognitoMode,
		&dest.HideOnlineStatus,

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
	dest.Photos = photos
	if socialLinks != nil {
		dest.SocialLinks = json.RawMessage(socialLinks)
	}

	return nil
}

func (r *matchRepository) GetMutualMatchUsers(ctx context.Context, userID, eventID string) ([]model.User, error) {
	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE m."isMutual" = true
		  AND (m."userAId" = $1 OR m."userBId" = $1)
		  AND ($2 = '' OR COALESCE(m."eventId", '') = COALESCE($2, ''))
		ORDER BY m."matchedAt" DESC NULLS LAST, m."updatedAt" DESC
	`

	rows, err := r.pool.Query(ctx, query, userID, eventID)
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

func (r *matchRepository) GetActionUsers(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE (CASE WHEN m."userAId" = $1 THEN m."userAAction" ELSE m."userBAction" END) = $3
		  AND (m."userAId" = $1 OR m."userBId" = $1)
		  AND ($4 = '' OR COALESCE(m."eventId", '') = COALESCE($4, ''))
		ORDER BY m."updatedAt" DESC
		LIMIT $2
	`

	rows, err := r.pool.Query(ctx, query, userID, limit, string(action), eventID)
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

func (r *matchRepository) GetIncomingLikeUsers(ctx context.Context, userID, eventID string, limit int) ([]model.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM "Match" m
		JOIN users."User" u ON u.id = CASE WHEN m."userAId" = $1 THEN m."userBId" ELSE m."userAId" END
		WHERE
			(m."userAId" = $1 OR m."userBId" = $1)
			AND (CASE WHEN m."userAId" = $1 THEN m."userBAction" ELSE m."userAAction" END) IN ($3, $4)
			AND (CASE WHEN m."userAId" = $1 THEN m."userAAction" ELSE m."userBAction" END) IS NULL
			AND m."isMutual" = false
			AND ($5 = '' OR COALESCE(m."eventId", '') = COALESCE($5, ''))
		ORDER BY m."updatedAt" DESC
		LIMIT $2
	`

	rows, err := r.pool.Query(
		ctx,
		query,
		userID,
		limit,
		string(model.MatchActionLike),
		string(model.MatchActionSuperLike),
		eventID,
	)
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

func (r *matchRepository) GetUserByID(ctx context.Context, userID string) (model.User, error) {
	query := `
		SELECT
			u.id, u."supabaseUid", u.email, u."displayName", u."photoUrl", COALESCE(u.photos, ARRAY[]::text[]), u.bio, u.interests,
			u."socialLinks", u.age, u.gender, u.role, u."lastLatitude", u."lastLongitude",
			u."lastLocationUpdate", u."isProfileVisible", u."isLocationVisible", u."showVisitedEvents", u."showInMatches", u."incognitoMode", u."hideOnlineStatus",
			u."minAge", u."maxAge", u."maxDistance", u."fcmToken", u."isOnboardingCompleted",
			u."createdAt", u."updatedAt"
		FROM users."User" u
		WHERE u.id = $1
		LIMIT 1
	`

	var user model.User
	if err := scanUser(r.pool.QueryRow(ctx, query, userID), &user); err != nil {
		return model.User{}, err
	}

	return user, nil
}
