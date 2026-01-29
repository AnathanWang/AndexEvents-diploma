package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
	"github.com/AnathanWang/andexevents/services/match-service/internal/service"
)

type MatchHandler struct {
	matchService service.MatchService
}

func NewMatchHandler(matchService service.MatchService) *MatchHandler {
	return &MatchHandler{matchService: matchService}
}

// GET /api/matches
func (h *MatchHandler) GetMyMutualMatches(c *gin.Context) {
	userID, ok := c.Get("dbUserID")
	if !ok {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	users, err := h.matchService.GetMutualMatches(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to fetch mutual matches",
		})
		return
	}

	c.JSON(http.StatusOK, model.UsersResponse{
		Success: true,
		Data:    users,
	})
}

// GET /api/matches/actions?action=LIKE|DISLIKE|SUPER_LIKE&limit=50
func (h *MatchHandler) GetMyActions(c *gin.Context) {
	userID, ok := c.Get("dbUserID")
	if !ok {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	actionRaw := c.Query("action")
	action := model.MatchAction(actionRaw)
	if !action.IsValid() {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: "Query param 'action' must be LIKE, DISLIKE, or SUPER_LIKE",
		})
		return
	}

	limit := 50
	if limitRaw := c.Query("limit"); limitRaw != "" {
		if parsed, err := strconv.Atoi(limitRaw); err == nil {
			if parsed < 1 {
				parsed = 1
			}
			if parsed > 200 {
				parsed = 200
			}
			limit = parsed
		}
	}

	users, err := h.matchService.GetUsersByAction(c.Request.Context(), userID.(string), action, limit)
	if err != nil {
		if errors.Is(err, service.ErrInvalidAction) {
			c.JSON(http.StatusBadRequest, model.ErrorResponse{
				Success: false,
				Message: "Query param 'action' must be LIKE, DISLIKE, or SUPER_LIKE",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: "Failed to fetch match actions",
		})
		return
	}

	c.JSON(http.StatusOK, model.UsersResponse{
		Success: true,
		Data:    users,
	})
}

func (h *MatchHandler) SendLike(c *gin.Context) {
	h.sendAction(c, model.MatchActionLike)
}

func (h *MatchHandler) SendDislike(c *gin.Context) {
	h.sendAction(c, model.MatchActionDislike)
}

func (h *MatchHandler) SendSuperLike(c *gin.Context) {
	h.sendAction(c, model.MatchActionSuperLike)
}

func (h *MatchHandler) sendAction(c *gin.Context, action model.MatchAction) {
	userID, ok := c.Get("dbUserID")
	if !ok {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse{
			Success: false,
			Message: "Unauthorized: User ID not found",
		})
		return
	}

	actionLabel := "action"
	selfMessage := "Cannot like yourself"
	failMessage := "Failed to send action"
	switch action {
	case model.MatchActionLike:
		actionLabel = "like"
		selfMessage = "Cannot like yourself"
		failMessage = "Failed to send like"
	case model.MatchActionDislike:
		actionLabel = "dislike"
		selfMessage = "Cannot dislike yourself"
		failMessage = "Failed to send dislike"
	case model.MatchActionSuperLike:
		actionLabel = "super like"
		selfMessage = "Cannot super like yourself"
		failMessage = "Failed to send super like"
	default:
		_ = actionLabel
	}

	var req model.LikeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: "targetUserId is required",
		})
		return
	}

	if userID.(string) == req.TargetUserID {
		c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Success: false,
			Message: selfMessage,
		})
		return
	}

	result, err := h.matchService.CreateOrUpdateMatch(c.Request.Context(), userID.(string), req.TargetUserID, action)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Success: false,
			Message: failMessage,
		})
		return
	}

	message := "Action recorded"
	if action == model.MatchActionLike {
		if result.IsMutual {
			message = "It's a match! 🎉"
		} else {
			message = "Like sent!"
		}
	} else if action == model.MatchActionSuperLike {
		if result.IsMutual {
			message = "It's a match! 🎉"
		} else {
			message = "Super like sent!"
		}
	} else if action == model.MatchActionDislike {
		message = "Dislike recorded"
	}

	c.JSON(http.StatusOK, model.MatchResponse{
		Success: true,
		Data:    result,
		Message: message,
	})
}
