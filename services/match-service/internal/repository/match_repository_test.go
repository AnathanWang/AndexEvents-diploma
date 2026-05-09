package repository

import (
	"context"
	"regexp"
	"testing"
	"time"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
)

func TestCreateOrUpdateMatch_NewMatch(t *testing.T) {
	mock, err := pgxmock.NewPool()
	assert.NoError(t, err)
	defer mock.Close()

	repo := NewMatchRepository(mock)

	userID := "user1"
	targetID := "user2"
	eventID := "event1"
	actionStr := string(model.MatchActionLike)
	action := model.MatchActionLike

	// 1. SELECT query expects NoRows
	mock.ExpectQuery(regexp.QuoteMeta(`SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt" FROM "Match"`)).
		WithArgs(userID, targetID, eventID).
		WillReturnError(pgx.ErrNoRows)

	// 2. INSERT query
	mock.ExpectQuery(regexp.QuoteMeta(`INSERT INTO "Match"`)).
		WithArgs(
			pgxmock.AnyArg(), // id
			userID,
			targetID,
			eventID,
			actionStr,
			pgxmock.AnyArg(), // now
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"}).
			AddRow("match1", userID, targetID, eventID, &actionStr, nil, false, nil, time.Now(), time.Now()))

	res, err := repo.CreateOrUpdateMatch(context.Background(), userID, targetID, eventID, action)
	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Equal(t, userID, res.UserAID)
	assert.Equal(t, targetID, res.UserBID)
	assert.Equal(t, eventID, res.EventID)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err)
}

func TestCreateOrUpdateMatch_UpdateExistingToMutual(t *testing.T) {
	mock, err := pgxmock.NewPool()
	assert.NoError(t, err)
	defer mock.Close()

	repo := NewMatchRepository(mock)

	userID := "user2" // targetID responds to user1
	targetID := "user1"
	eventID := "event1"
	action := model.MatchActionLike

	// Existing: user1 liked user2
	user1Action := string(model.MatchActionLike)

	// 1. SELECT returns an existing row where userA = user1, userB = user2
	mock.ExpectQuery(regexp.QuoteMeta(`SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt" FROM "Match"`)).
		WithArgs(userID, targetID, eventID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"}).
			AddRow("match1", targetID, userID, eventID, &user1Action, nil, false, nil, time.Now(), time.Now()))

	now := time.Now()
	// 2. UPDATE query
	// The current user reacting is user2, which corresponds to userB in the DB. So setColumn will be "userBAction"
	actionStr := string(action)
	mock.ExpectQuery(regexp.QuoteMeta(`UPDATE "Match"`)).
		WithArgs(
			actionStr,
			true, // isMutual should be true
			pgxmock.AnyArg(),
			pgxmock.AnyArg(),
			"match1", // id
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"}).
			AddRow("match1", targetID, userID, eventID, &user1Action, &actionStr, true, &now, time.Now(), time.Now()))

	res, err := repo.CreateOrUpdateMatch(context.Background(), userID, targetID, eventID, action)
	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.True(t, res.IsMutual)
	assert.Equal(t, eventID, res.EventID)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err)
}

func TestCreateOrUpdateMatch_DifferentEventIDs(t *testing.T) {
	mock, err := pgxmock.NewPool()
	assert.NoError(t, err)
	defer mock.Close()

	repo := NewMatchRepository(mock)

	userID := "user1"
	targetID := "user2"
	eventID1 := "event1"
	eventID2 := "event2"
	action := model.MatchActionLike
	actionStr := string(action)

	// First match created for event1
	mock.ExpectQuery(regexp.QuoteMeta(`SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt" FROM "Match"`)).
		WithArgs(userID, targetID, eventID1).
		WillReturnError(pgx.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta(`INSERT INTO "Match"`)).
		WithArgs(pgxmock.AnyArg(), userID, targetID, eventID1, actionStr, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"}).
			AddRow("match1", userID, targetID, eventID1, &actionStr, nil, false, nil, time.Now(), time.Now()))

	res1, err := repo.CreateOrUpdateMatch(context.Background(), userID, targetID, eventID1, action)
	assert.NoError(t, err)
	assert.Equal(t, eventID1, res1.EventID)

	// Second match created for event2 - SELECT comes back empty
	mock.ExpectQuery(regexp.QuoteMeta(`SELECT id, "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt" FROM "Match"`)).
		WithArgs(userID, targetID, eventID2).
		WillReturnError(pgx.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta(`INSERT INTO "Match"`)).
		WithArgs(pgxmock.AnyArg(), userID, targetID, eventID2, actionStr, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "userAId", "userBId", "eventId", "userAAction", "userBAction", "isMutual", "matchedAt", "createdAt", "updatedAt"}).
			AddRow("match2", userID, targetID, eventID2, &actionStr, nil, false, nil, time.Now(), time.Now()))

	res2, err := repo.CreateOrUpdateMatch(context.Background(), userID, targetID, eventID2, action)
	assert.NoError(t, err)
	assert.Equal(t, eventID2, res2.EventID)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err)
}
