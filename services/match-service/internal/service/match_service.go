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
	CreateOrUpdateMatch(ctx context.Context, userID, targetUserID string, action model.MatchAction) (*model.Match, error)
	GetMutualMatches(ctx context.Context, userID string) ([]model.User, error)
	GetUsersByAction(ctx context.Context, userID string, action model.MatchAction, limit int) ([]model.User, error)
}

type matchService struct {
	repo repository.MatchRepository
}

func NewMatchService(repo repository.MatchRepository) MatchService {
	return &matchService{repo: repo}
}

func (s *matchService) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID string, action model.MatchAction) (*model.Match, error) {
	if !action.IsValid() {
		return nil, ErrInvalidAction
	}
	return s.repo.CreateOrUpdateMatch(ctx, userID, targetUserID, action)
}

func (s *matchService) GetMutualMatches(ctx context.Context, userID string) ([]model.User, error) {
	return s.repo.GetMutualMatchUsers(ctx, userID)
}

func (s *matchService) GetUsersByAction(ctx context.Context, userID string, action model.MatchAction, limit int) ([]model.User, error) {
	if !action.IsValid() {
		return nil, ErrInvalidAction
	}
	return s.repo.GetActionUsers(ctx, userID, action, limit)
}
