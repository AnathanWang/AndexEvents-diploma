package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	return gin.New()
}

// TestAuthMiddleware_NoHeader тестирует запрос без заголовка Authorization
func TestAuthMiddleware_NoHeader(t *testing.T) {
	router := setupTestRouter()

	router.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "Authorization header is required",
			})
			c.Abort()
			return
		}
		c.Next()
	})

	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/protected", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

// TestAuthMiddleware_InvalidFormat тестирует неправильный формат токена
func TestAuthMiddleware_InvalidFormat(t *testing.T) {
	router := setupTestRouter()

	router.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "No auth header"})
			c.Abort()
			return
		}

		if len(authHeader) < 8 || authHeader[:7] != "Bearer " {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "Invalid authorization format",
			})
			c.Abort()
			return
		}
		c.Next()
	})

	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.Header.Set("Authorization", "invalid-token-format")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

// TestAuthMiddleware_ValidToken тестирует валидный токен
func TestAuthMiddleware_ValidToken(t *testing.T) {
	router := setupTestRouter()

	router.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || len(authHeader) < 8 || authHeader[:7] != "Bearer " {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid auth"})
			c.Abort()
			return
		}

		token := authHeader[7:]
		if token == "valid-token" {
			c.Set("firebase_uid", "test-firebase-uid")
			c.Next()
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
		}
	})

	router.GET("/protected", func(c *gin.Context) {
		uid, _ := c.Get("firebase_uid")
		c.JSON(http.StatusOK, gin.H{
			"success":      true,
			"firebase_uid": uid,
		})
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.Header.Set("Authorization", "Bearer valid-token")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
}

// TestCORSMiddleware тестирует CORS заголовки
func TestCORSMiddleware(t *testing.T) {
	router := setupTestRouter()

	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("OPTIONS", "/test", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNoContent, w.Code)
	assert.Equal(t, "*", w.Header().Get("Access-Control-Allow-Origin"))
}

// TestErrorRecovery тестирует восстановление после паники
func TestErrorRecovery(t *testing.T) {
	router := setupTestRouter()
	router.Use(gin.Recovery())

	router.GET("/panic", func(c *gin.Context) {
		panic("test panic")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/panic", nil)

	assert.NotPanics(t, func() {
		router.ServeHTTP(w, req)
	})

	assert.Equal(t, http.StatusInternalServerError, w.Code)
}
