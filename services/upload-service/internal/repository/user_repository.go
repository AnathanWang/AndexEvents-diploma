package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

// GetDBUserIDByFirebaseUID maps Firebase UID to our internal User.id.
// Current schema uses `supabaseUid` column; during Firebase migration we store Firebase UID there.
func (r *UserRepository) GetDBUserIDByFirebaseUID(ctx context.Context, firebaseUID string) (string, error) {
	var userID string
	err := r.pool.QueryRow(ctx, `SELECT id FROM "User" WHERE "supabaseUid" = $1`, firebaseUID).Scan(&userID)
	if err != nil {
		return "", err
	}
	return userID, nil
}

func (r *UserRepository) UpdateUserPhotoURL(ctx context.Context, userID string, photoURL string) error {
	_, err := r.pool.Exec(ctx, `UPDATE "User" SET "photoUrl" = $1 WHERE id = $2`, photoURL, userID)
	return err
}
