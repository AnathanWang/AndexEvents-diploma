package service

import (
	"context"
	"errors"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
	"github.com/AnathanWang/andexevents/services/match-service/internal/repository"
)

var (
	ErrInvalidAction = errors.New("invalid match action")
)

type MatchService interface {
	CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error)
	GetMutualMatches(ctx context.Context, userID, eventID string) ([]model.User, error)
	GetUsersByAction(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error)
	GetIncomingLikes(ctx context.Context, userID, eventID string, limit int) ([]model.User, error)
}

type matchService struct {
	repo     repository.MatchRepository
	notifier PushNotifier
}

func NewMatchService(repo repository.MatchRepository, notifier PushNotifier) MatchService {
	if notifier == nil {
		notifier = noopNotifier{}
	}

	return &matchService{repo: repo, notifier: notifier}
}

func (s *matchService) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID, eventID string, action model.MatchAction) (*model.Match, error) {
	if !action.IsValid() {
		return nil, ErrInvalidAction
	}

	match, err := s.repo.CreateOrUpdateMatch(ctx, userID, targetUserID, eventID, action)
	if err != nil {
		return nil, err
	}

	if action.IsLikeType() && !match.IsMutual {
		fromUser, fromErr := s.repo.GetUserByID(ctx, userID)
		toUser, toErr := s.repo.GetUserByID(ctx, targetUserID)
		if fromErr == nil && toErr == nil {
			_ = s.notifier.NotifyIncomingLike(ctx, fromUser, toUser, action)
		}
	}

	return match, nil
}

func (s *matchService) GetMutualMatches(ctx context.Context, userID, eventID string) ([]model.User, error) {
	return s.repo.GetMutualMatchUsers(ctx, userID, eventID)
}

func (s *matchService) GetUsersByAction(ctx context.Context, userID, eventID string, action model.MatchAction, limit int) ([]model.User, error) {
	if !action.IsValid() {
		return nil, ErrInvalidAction
	}
	return s.repo.GetActionUsers(ctx, userID, eventID, action, limit)
}

func (s *matchService) GetIncomingLikes(ctx context.Context, userID, eventID string, limit int) ([]model.User, error) {
	return s.repo.GetIncomingLikeUsers(ctx, userID, eventID, limit)
}
