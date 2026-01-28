package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	firebase "firebase.google.com/go/v4"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
	"google.golang.org/api/option"

	"github.com/AnathanWang/andexevents/services/events-service/internal/config"
	"github.com/AnathanWang/andexevents/services/events-service/internal/handler"
	"github.com/AnathanWang/andexevents/services/events-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/events-service/internal/repository"
	"github.com/AnathanWang/andexevents/services/events-service/internal/service"
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

	// Инициализируем Firebase
	opt := option.WithCredentialsFile(cfg.FirebaseCredentialsFile)
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		logger.Fatal("Failed to initialize Firebase", zap.Error(err))
	}

	authClient, err := app.Auth(context.Background())
	if err != nil {
		logger.Fatal("Failed to get Firebase auth client", zap.Error(err))
	}

	// Инициализируем слои приложения
	eventRepo := repository.NewEventRepository(pool)
	participantRepo := repository.NewParticipantRepository(pool)
	eventService := service.NewEventService(eventRepo, participantRepo)
	eventHandler := handler.NewEventHandler(eventService)

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
			"service": "events-service",
		})
	})

	// API routes
	api := router.Group("/api/events")
	{
		// Public routes
		api.GET("", eventHandler.GetEvents)
		api.GET("/:id", eventHandler.GetEventByID)
		api.GET("/user/:userId", eventHandler.GetUserEvents)
		api.GET("/:id/participants", eventHandler.GetParticipants)

		// Protected routes
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(authClient))
		{
			protected.POST("", eventHandler.CreateEvent)
			protected.PUT("/:id", eventHandler.UpdateEvent)
			protected.DELETE("/:id", eventHandler.DeleteEvent)
			protected.POST("/:id/participate", eventHandler.JoinEvent)
			protected.DELETE("/:id/participate", eventHandler.LeaveEvent)
		}
	}

	// Запускаем сервер
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Port),
		Handler: router,
	}

	go func() {
		logger.Info("Starting events-service", zap.Int("port", cfg.Port))
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
