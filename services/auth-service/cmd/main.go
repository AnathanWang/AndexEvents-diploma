// Auth Service - микросервис авторизации и управления пользователями
//
// Отвечает за:
// - Регистрацию и авторизацию через Firebase Auth
// - CRUD операции с профилями пользователей
// - Обновление геолокации
// - Поиск потенциальных мэтчей
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/auth-service/internal/config"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/handler"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/repository"
	"github.com/AnathanWang/andexevents/services/auth-service/internal/service"
	"github.com/AnathanWang/andexevents/shared/pkg/database"
	"github.com/AnathanWang/andexevents/shared/pkg/firebase"
	"github.com/AnathanWang/andexevents/shared/pkg/logger"
)

const (
	serviceName = "auth-service"
	version     = "1.0.0"
)

func main() {
	// Загружаем конфигурацию
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// Инициализируем логгер
	if err := logger.Init(logger.Config{
		Level:       "debug",
		Environment: cfg.Environment,
		ServiceName: serviceName,
	}); err != nil {
		fmt.Printf("Failed to init logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	logger.Info("Starting service",
		zap.String("service", serviceName),
		zap.String("version", version),
		zap.String("environment", cfg.Environment),
	)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Подключаемся к базе данных
	db, err := database.NewPool(ctx, database.Config{
		Host:     cfg.DBHost,
		Port:     cfg.DBPort,
		User:     cfg.DBUser,
		Password: cfg.DBPassword,
		Database: cfg.DBName,
		SSLMode:  cfg.DBSSLMode,
	})
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer db.Close()
	logger.Info("Connected to database")

	// Инициализируем Firebase (опционально в development)
	var firebaseClient *firebase.Client
	if cfg.FirebaseCredentialsFile != "" {
		firebaseClient, err = firebase.NewClient(ctx, firebase.Config{
			CredentialsFile: cfg.FirebaseCredentialsFile,
			ProjectID:       cfg.FirebaseProjectID,
		})
		if err != nil {
			logger.Fatal("Failed to initialize Firebase", zap.Error(err))
		}
		logger.Info("Firebase initialized")
	} else {
		logger.Warn("Firebase credentials not configured, running without auth verification")
	}

	// Инициализируем слои приложения
	userRepo := repository.NewUserRepository(db)
	userService := service.NewUserService(userRepo)
	healthHandler := handler.NewHealthHandler(serviceName, version)
	userHandler := handler.NewUserHandler(userService)

	// Настраиваем Gin
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(loggerMiddleware())
	router.Use(corsMiddleware())

	// Health endpoints (без авторизации)
	router.GET("/health", healthHandler.Health)
	router.GET("/ready", healthHandler.Ready)

	// API routes
	api := router.Group("/api")
	{
		// Auth routes
		auth := api.Group("/auth")
		{
			// Verify endpoint для проверки токена
			if firebaseClient != nil {
				auth.POST("/verify", middleware.AuthMiddleware(firebaseClient), func(c *gin.Context) {
					uid, _ := middleware.GetFirebaseUID(c)
					c.JSON(http.StatusOK, gin.H{
						"success":     true,
						"firebaseUid": uid,
					})
				})
			}
		}

		// Users routes
		users := api.Group("/users")
		{
			// Protected routes
			if firebaseClient != nil {
				protected := users.Group("")
				protected.Use(middleware.AuthMiddleware(firebaseClient))
				{
					protected.POST("", userHandler.CreateUser)
					protected.GET("/me", userHandler.GetMe)
					protected.PUT("/me", userHandler.UpdateMe)
					protected.PUT("/me/location", userHandler.UpdateLocation)
					protected.POST("/me/onboarding", userHandler.CompleteOnboarding)
					protected.GET("/matches", userHandler.GetMatches)
				}
			}

			// Public routes
			users.GET("/:id", userHandler.GetUser)
		}
	}

	// Запускаем сервер
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		logger.Info("Server starting", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed", zap.Error(err))
		}
	}()

	// Ждём сигнал завершения
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Даём 10 секунд на завершение запросов
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server stopped")
}

// loggerMiddleware middleware для логирования запросов
func loggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		logger.Info("HTTP Request",
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.String("query", query),
			zap.Duration("latency", latency),
			zap.String("ip", c.ClientIP()),
			zap.String("userAgent", c.Request.UserAgent()),
		)
	}
}

// corsMiddleware middleware для CORS
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
