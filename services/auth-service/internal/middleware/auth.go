// Package middleware содержит HTTP middleware для авторизации.
//
// Middleware - это функции, которые выполняются до/после handler'а.
// Используются для: авторизации, логирования, CORS, rate limiting и т.д.
package middleware

import (
	"context"
	"strings"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/shared/pkg/firebase"
	"github.com/AnathanWang/andexevents/shared/pkg/logger"
	"github.com/AnathanWang/andexevents/shared/pkg/response"
)

// ContextKey тип для ключей контекста
type ContextKey string

const (
	FirebaseUIDKey ContextKey = "firebaseUID"
	UserIDKey      ContextKey = "userID"
	EmailKey       ContextKey = "email"
)

// AuthMiddleware middleware для проверки Firebase токена
// Требует валидный токен - без него запрос отклоняется
func AuthMiddleware(firebaseClient *firebase.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Получаем заголовок Authorization
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "Authorization header is required")
			c.Abort()
			return
		}

		// Парсим "Bearer <token>"
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			response.Unauthorized(c, "Invalid authorization header format")
			c.Abort()
			return
		}

		idToken := parts[1]

		// Верифицируем токен через Firebase
		token, err := firebaseClient.VerifyToken(c.Request.Context(), idToken)
		if err != nil {
			logger.Warn("Failed to verify Firebase token",
				zap.Error(err),
				zap.String("ip", c.ClientIP()),
			)
			response.Unauthorized(c, "Invalid or expired token")
			c.Abort()
			return
		}

		// Сохраняем данные в контекст Gin
		c.Set(string(FirebaseUIDKey), token.UID)

		// Извлекаем email если есть
		if email, ok := token.Claims["email"].(string); ok {
			c.Set(string(EmailKey), email)
		}

		logger.Debug("Token verified successfully",
			zap.String("firebaseUID", token.UID),
		)

		c.Next()
	}
}

// OptionalAuthMiddleware middleware для опциональной авторизации
// Если токен есть и валидный - извлекаем данные
// Если нет - просто пропускаем запрос
func OptionalAuthMiddleware(firebaseClient *firebase.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.Next()
			return
		}

		idToken := parts[1]

		token, err := firebaseClient.VerifyToken(c.Request.Context(), idToken)
		if err != nil {
			// Токен невалидный, но это не критично для optional auth
			c.Next()
			return
		}

		c.Set(string(FirebaseUIDKey), token.UID)
		if email, ok := token.Claims["email"].(string); ok {
			c.Set(string(EmailKey), email)
		}

		c.Next()
	}
}

// GetFirebaseUID извлекает Firebase UID из контекста Gin
func GetFirebaseUID(c *gin.Context) (string, bool) {
	uid, exists := c.Get(string(FirebaseUIDKey))
	if !exists {
		return "", false
	}
	return uid.(string), true
}

// GetUserID извлекает ID пользователя из контекста
func GetUserID(c *gin.Context) (string, bool) {
	id, exists := c.Get(string(UserIDKey))
	if !exists {
		return "", false
	}
	return id.(string), true
}

// GetEmail извлекает email из контекста
func GetEmail(c *gin.Context) (string, bool) {
	email, exists := c.Get(string(EmailKey))
	if !exists {
		return "", false
	}
	return email.(string), true
}

// SetUserID устанавливает ID пользователя в контекст
func SetUserID(c *gin.Context, userID string) {
	c.Set(string(UserIDKey), userID)
}

// WithFirebaseUID добавляет Firebase UID в context.Context
func WithFirebaseUID(ctx context.Context, uid string) context.Context {
	return context.WithValue(ctx, FirebaseUIDKey, uid)
}

// FirebaseUIDFromContext извлекает Firebase UID из context.Context
func FirebaseUIDFromContext(ctx context.Context) (string, bool) {
	uid, ok := ctx.Value(FirebaseUIDKey).(string)
	return uid, ok
}
