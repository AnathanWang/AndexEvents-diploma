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

	"github.com/AnathanWang/andexevents/services/upload-service/internal/config"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/handler"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/repository"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/storage"
	"github.com/AnathanWang/andexevents/shared/pkg/firebase"
)

func main() {
	cfg := config.Load()

	var logger *zap.Logger
	if cfg.Environment == "production" {
		logger, _ = zap.NewProduction()
	} else {
		logger, _ = zap.NewDevelopment()
	}
	defer logger.Sync()

	firebaseClient, err := firebase.NewClient(context.Background(), firebase.Config{
		CredentialsFile: cfg.FirebaseCredentialsFile,
		ProjectID:       cfg.FirebaseProjectID,
	})
	if err != nil {
		logger.Fatal("Failed to initialize Firebase", zap.Error(err))
	}

	dbURL := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName, cfg.DBSSLMode,
	)

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		logger.Fatal("Failed to ping database", zap.Error(err))
	}
	logger.Info("Connected to database")

	minioClient, err := storage.NewMinioClient(cfg)
	if err != nil {
		logger.Fatal("Failed to initialize MinIO client", zap.Error(err))
	}

	userRepo := repository.NewUserRepository(pool)
	uploadHandler := handler.NewUploadHandler(logger, userRepo, minioClient, cfg.UploadsPublicBaseURL)
	uploadsHandler := handler.NewUploadsHandler(logger, minioClient)

	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.LoggerMiddleware(logger))
	router.Use(middleware.CORSMiddleware())

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "upload-service",
		})
	})

	// Public files (drop-in replacement for Node `/uploads/...`).
	router.GET("/uploads/:bucket/:userId/:filename", uploadsHandler.GetUpload)

	// Node-compatible upload endpoint.
	api := router.Group("/api/upload")
	{
		api.Use(middleware.FirebaseAuthMiddleware(logger, firebaseClient, userRepo))
		api.POST("", uploadHandler.UploadFile)
	}

	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Port),
		Handler: router,
	}

	go func() {
		logger.Info("Starting upload-service", zap.Int("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

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
