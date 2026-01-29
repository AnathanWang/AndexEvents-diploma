package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type MockMatchService struct {
	mock.Mock
}

func (m *MockMatchService) CreateOrUpdateMatch(ctx context.Context, userID, targetUserID string, action model.MatchAction) (*model.Match, error) {
	args := m.Called(ctx, userID, targetUserID, action)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Match), args.Error(1)
}

func (m *MockMatchService) GetMutualMatches(ctx context.Context, userID string) ([]model.User, error) {
	args := m.Called(ctx, userID)
	return args.Get(0).([]model.User), args.Error(1)
}

func (m *MockMatchService) GetUsersByAction(ctx context.Context, userID string, action model.MatchAction, limit int) ([]model.User, error) {
	args := m.Called(ctx, userID, action, limit)
	return args.Get(0).([]model.User), args.Error(1)
}

func setupRouter(mockService *MockMatchService) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	h := NewMatchHandler(mockService)

	api := router.Group("/api/matches")
	{
		api.GET("", setDBUserID("user-123"), h.GetMyMutualMatches)
		api.GET("/actions", setDBUserID("user-123"), h.GetMyActions)
		api.POST("/like", setDBUserID("user-123"), h.SendLike)
	}

	return router
}

func setDBUserID(userID string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("dbUserID", userID)
		c.Next()
	}
}

func TestGetMyActions_InvalidAction(t *testing.T) {
	mockSvc := new(MockMatchService)
	router := setupRouter(mockSvc)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/api/matches/actions?action=NOPE", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestSendLike_MissingTargetUserID(t *testing.T) {
	mockSvc := new(MockMatchService)
	router := setupRouter(mockSvc)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodPost, "/api/matches/like", bytes.NewBufferString(`{}`))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestSendLike_Success(t *testing.T) {
	mockSvc := new(MockMatchService)
	router := setupRouter(mockSvc)

	match := &model.Match{ID: "m1", UserAID: "user-123", UserBID: "user-456", IsMutual: false}
	mockSvc.On("CreateOrUpdateMatch", mock.Anything, "user-123", "user-456", model.MatchActionLike).Return(match, nil)

	body, _ := json.Marshal(model.LikeRequest{TargetUserID: "user-456"})
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodPost, "/api/matches/like", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	mockSvc.AssertExpectations(t)
}
