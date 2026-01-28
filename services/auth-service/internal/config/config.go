// Package config загружает конфигурацию из переменных окружения.
//
// Почему переменные окружения, а не конфиг файлы?
// 1. 12-factor app принцип - конфиг в окружении
// 2. Легко переопределить в Docker/Kubernetes
// 3. Секреты не попадают в Git
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config конфигурация auth-service
type Config struct {
	// Server
	Port        string
	Environment string // development, production

	// Database
	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	// Redis
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// Firebase
	FirebaseCredentialsFile string
	FirebaseProjectID       string

	// JWT
	JWTSecret     string
	JWTExpiration time.Duration
}

// Load загружает конфигурацию из переменных окружения
func Load() (*Config, error) {
	cfg := &Config{
		// Server
		Port:        getEnv("PORT", "8001"),
		Environment: getEnv("ENVIRONMENT", "development"),

		// Database
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnvAsInt("DB_PORT", 5432),
		DBUser:     getEnv("DB_USER", "andexadmin"),
		DBPassword: getEnv("DB_PASSWORD", "andexevents"),
		DBName:     getEnv("DB_NAME", "andexevents"),
		DBSSLMode:  getEnv("DB_SSL_MODE", "disable"),

		// Redis
		RedisAddr:     getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),
		RedisDB:       getEnvAsInt("REDIS_DB", 0),

		// Firebase
		FirebaseCredentialsFile: getEnv("FIREBASE_CREDENTIALS_FILE", ""),
		FirebaseProjectID:       getEnv("FIREBASE_PROJECT_ID", ""),

		// JWT
		JWTSecret:     getEnv("JWT_SECRET", "your-super-secret-key"),
		JWTExpiration: getEnvAsDuration("JWT_EXPIRATION", 7*24*time.Hour),
	}

	// Валидация обязательных полей
	if cfg.FirebaseCredentialsFile == "" && cfg.Environment == "production" {
		return nil, fmt.Errorf("FIREBASE_CREDENTIALS_FILE is required in production")
	}

	return cfg, nil
}

// getEnv получает значение переменной окружения или возвращает default
func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// getEnvAsInt получает int из переменной окружения
func getEnvAsInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// getEnvAsDuration получает duration из переменной окружения
func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	if value, exists := os.LookupEnv(key); exists {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}
