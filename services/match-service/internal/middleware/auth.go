package middleware

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/AnathanWang/andexevents/shared/pkg/firebase"
)

var errTokenNotConfigured = errors.New("firebase not configured")

// AuthMiddleware verifies Firebase ID token.
// It sets in context:
// - userID: Firebase UID (stored in DB column "User"."supabaseUid" for now)
// - email: token email (if present)
// - dbUserID: UUID from table "User" if found
func AuthMiddleware(firebaseClient *firebase.Client, pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if firebaseClient == nil {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": errTokenNotConfigured.Error()})
			c.Abort()
			return
		}

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Unauthorized: No token provided",
			})
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Unauthorized: Invalid token format",
			})
			c.Abort()
			return
		}

		idToken := parts[1]
		token, err := firebaseClient.VerifyToken(c.Request.Context(), idToken)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized: Invalid token"})
			c.Abort()
			return
		}

		uid := token.UID
		if uid == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized: Token missing uid"})
			c.Abort()
			return
		}

		c.Set("userID", uid)
		if email, ok := token.Claims["email"].(string); ok && email != "" {
			c.Set("email", email)
		}

		var dbUserID string
		err = pool.QueryRow(c.Request.Context(),
			`SELECT id FROM "User" WHERE "supabaseUid" = $1`, uid,
		).Scan(&dbUserID)

		if err == nil {
			c.Set("dbUserID", dbUserID)
		}

		c.Next()
	}
}
