package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AuthMiddleware создаёт middleware для проверки Supabase JWT токена.
// Устанавливает в context:
// - userID (supabase uid) из claim sub
// - email (если есть)
// - dbUserID (uuid пользователя из таблицы "User"), если найден
func AuthMiddleware(jwtSecret string, pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
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

		tokenString := parts[1]

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Unauthorized: Invalid token",
			})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Unauthorized: Invalid token claims",
			})
			c.Abort()
			return
		}

		sub, ok := claims["sub"].(string)
		if !ok || sub == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Unauthorized: Token missing sub claim",
			})
			c.Abort()
			return
		}

		email, _ := claims["email"].(string)

		c.Set("userID", sub)
		c.Set("email", email)

		var dbUserID string
		err = pool.QueryRow(c.Request.Context(),
			`SELECT id FROM "User" WHERE "supabaseUid" = $1`, sub,
		).Scan(&dbUserID)

		if err == nil {
			c.Set("dbUserID", dbUserID)
		}

		c.Next()
	}
}
