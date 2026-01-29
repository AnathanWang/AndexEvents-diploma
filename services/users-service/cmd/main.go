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
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/users-service/internal/config"
	"github.com/AnathanWang/andexevents/services/users-service/internal/handler"
	"github.com/AnathanWang/andexevents/services/users-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/users-service/internal/repository"
	"github.com/AnathanWang/andexevents/services/users-service/internal/service"
)

func main() {
	// Загружаем конфигурацию
	cfg := config.Load()

	// Инициализируем логгер
	var logger *zap.Logger
	if cfg.Environment == "production" {
		logger, _ = zap.NewProduction()
	} else {
		logger, _ = zap.NewDevelopment()
	}
	defer logger.Sync()

	// Проверяем обязательные настройки
	if cfg.SupabaseJWTSecret == "" {
		logger.Fatal("SUPABASE_JWT_SECRET is required")
	}

	// Подключаемся к базе данных
	dbURL := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=disable",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName,
	)

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer pool.Close()

	// Проверяем подключение к БД
	if err := pool.Ping(context.Background()); err != nil {
		logger.Fatal("Failed to ping database", zap.Error(err))
	}
	logger.Info("Connected to database")

	// Инициализируем слои приложения
	userRepo := repository.NewUserRepository(pool)
	userService := service.NewUserService(userRepo, logger)
	userHandler := handler.NewUserHandler(userService)

	// Настраиваем Gin
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.LoggerMiddleware(logger))
	router.Use(middleware.CORSMiddleware())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "users-service",
		})
	})

	// API routes
	api := router.Group("/api/users")
	{
		// Все маршруты защищены авторизацией
		api.Use(middleware.AuthMiddleware(cfg.SupabaseJWTSecret, pool))

		// POST /api/users - создание пользователя
		api.POST("", userHandler.CreateUser)

		// GET /api/users/me - получить текущего пользователя
		api.GET("/me", userHandler.GetCurrentUser)

		// PUT /api/users/me - обновить профиль
		api.PUT("/me", userHandler.UpdateProfile)

		// PUT /api/users/me/location - обновить локацию
		api.PUT("/me/location", userHandler.UpdateLocation)

		// GET /api/users/matches - получить матчи
		api.GET("/matches", userHandler.GetMatches)
	}

	// Запускаем сервер
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Port),
		Handler: router,
	}

	go func() {
		logger.Info("Starting users-service", zap.Int("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server exited properly")
}
