package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/upload-service/internal/repository"
	"github.com/AnathanWang/andexevents/shared/pkg/firebase"
)

type contextKey string

const (
	ctxFirebaseUIDKey contextKey = "firebaseUID"
	ctxDBUserIDKey    contextKey = "dbUserID"
)

func FirebaseAuthMiddleware(logger *zap.Logger, firebaseClient *firebase.Client, userRepo *repository.UserRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
			c.Abort()
			return
		}

		idToken := parts[1]
		token, err := firebaseClient.VerifyToken(c.Request.Context(), idToken)
		if err != nil {
			logger.Warn("Failed to verify Firebase token", zap.Error(err))
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
			c.Abort()
			return
		}

		firebaseUID := token.UID
		if firebaseUID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
			c.Abort()
			return
		}

		dbUserID, err := userRepo.GetDBUserIDByFirebaseUID(c.Request.Context(), firebaseUID)
		if err != nil {
			// User not found (or DB error). Treat as unauthorized for drop-in client behavior.
			logger.Warn("Failed to map Firebase UID to DB user", zap.String("firebaseUID", firebaseUID), zap.Error(err))
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
			c.Abort()
			return
		}

		c.Set(string(ctxFirebaseUIDKey), firebaseUID)
		c.Set(string(ctxDBUserIDKey), dbUserID)

		c.Next()
	}
}

func GetDBUserID(c *gin.Context) (string, bool) {
	value, ok := c.Get(string(ctxDBUserIDKey))
	if !ok {
		return "", false
	}
	id, ok := value.(string)
	return id, ok && id != ""
}
