package config

import (
	"os"
	"strconv"
)

// Config содержит конфигурацию users-service
type Config struct {
	Port                    int
	Environment             string
	DBHost                  string
	DBPort                  int
	DBUser                  string
	DBPassword              string
	DBName                  string
	FirebaseProjectID       string
	FirebaseCredentialsFile string
	SupabaseJWTSecret       string
}

// Load загружает конфигурацию из переменных окружения
func Load() *Config {
	return &Config{
		Port:                    getEnvInt("PORT", 8003),
		Environment:             getEnv("ENVIRONMENT", "development"),
		DBHost:                  getEnv("DB_HOST", "localhost"),
		DBPort:                  getEnvInt("DB_PORT", 5432),
		DBUser:                  getEnv("DB_USER", "andexadmin"),
		DBPassword:              getEnv("DB_PASSWORD", "andexevents"),
		DBName:                  getEnv("DB_NAME", "andexevents"),
		FirebaseProjectID:       getEnv("FIREBASE_PROJECT_ID", ""),
		FirebaseCredentialsFile: getEnv("FIREBASE_CREDENTIALS_FILE", ""),
		SupabaseJWTSecret:       getEnv("SUPABASE_JWT_SECRET", ""),
	}
}

func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
