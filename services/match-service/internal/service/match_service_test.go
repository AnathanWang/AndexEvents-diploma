package service

import (
	"context"
	"errors"
	"testing"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type fakeRepo struct {
	matchResult model.Match
	matchErr    error
	users       map[string]model.User
}

func (r *fakeRepo) CreateOrUpdateMatch(context.Context, string, string, string, model.MatchAction) (*model.Match, error) {
	if r.matchErr != nil {
		return nil, r.matchErr
	}
	result := r.matchResult
	return &result, nil
}

func (r *fakeRepo) GetMutualMatchUsers(context.Context, string, string) ([]model.User, error) {
	return nil, nil
}

func (r *fakeRepo) GetActionUsers(context.Context, string, string, model.MatchAction, int) ([]model.User, error) {
	return nil, nil
}

func (r *fakeRepo) GetIncomingLikeUsers(context.Context, string, string, int) ([]model.User, error) {
	return nil, nil
}

func (r *fakeRepo) GetUserByID(_ context.Context, userID string) (model.User, error) {
	user, ok := r.users[userID]
	if !ok {
		return model.User{}, errors.New("user not found")
	}
	return user, nil
}

type fakeNotifier struct {
	calls int
}

func (n *fakeNotifier) NotifyIncomingLike(context.Context, model.User, model.User, model.MatchAction) error {
	n.calls++
	return nil
}

func TestCreateOrUpdateMatch_SendsNotificationForIncomingLike(t *testing.T) {
	fromName := "Alice"
	toToken := "token-123"
	repo := &fakeRepo{
		matchResult: model.Match{IsMutual: false},
		users: map[string]model.User{
			"from": {ID: "from", DisplayName: &fromName},
			"to":   {ID: "to", FCMToken: &toToken},
		},
	}
	notifier := &fakeNotifier{}
	svc := NewMatchService(repo, notifier)

	_, err := svc.CreateOrUpdateMatch(context.Background(), "from", "to", "", model.MatchActionLike)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if notifier.calls != 1 {
		t.Fatalf("expected notifier to be called once, got %d", notifier.calls)
	}
}

func TestCreateOrUpdateMatch_DoesNotSendForMutual(t *testing.T) {
	fromName := "Alice"
	toToken := "token-123"
	repo := &fakeRepo{
		matchResult: model.Match{IsMutual: true},
		users: map[string]model.User{
			"from": {ID: "from", DisplayName: &fromName},
			"to":   {ID: "to", FCMToken: &toToken},
		},
	}
	notifier := &fakeNotifier{}
	svc := NewMatchService(repo, notifier)

	_, err := svc.CreateOrUpdateMatch(context.Background(), "from", "to", "", model.MatchActionLike)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if notifier.calls != 0 {
		t.Fatalf("expected notifier to not be called, got %d", notifier.calls)
	}
}

func TestCreateOrUpdateMatch_DoesNotSendForDislike(t *testing.T) {
	fromName := "Alice"
	toToken := "token-123"
	repo := &fakeRepo{
		matchResult: model.Match{IsMutual: false},
		users: map[string]model.User{
			"from": {ID: "from", DisplayName: &fromName},
			"to":   {ID: "to", FCMToken: &toToken},
		},
	}
	notifier := &fakeNotifier{}
	svc := NewMatchService(repo, notifier)

	_, err := svc.CreateOrUpdateMatch(context.Background(), "from", "to", "", model.MatchActionDislike)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if notifier.calls != 0 {
		t.Fatalf("expected notifier to not be called, got %d", notifier.calls)
	}
}

func TestCreateOrUpdateMatch_PropagatesRepositoryError(t *testing.T) {
	repo := &fakeRepo{matchErr: errors.New("db failed")}
	notifier := &fakeNotifier{}
	svc := NewMatchService(repo, notifier)

	_, err := svc.CreateOrUpdateMatch(context.Background(), "from", "to", "", model.MatchActionLike)
	if err == nil {
		t.Fatal("expected error")
	}
	if notifier.calls != 0 {
		t.Fatalf("expected notifier to not be called, got %d", notifier.calls)
	}
}
