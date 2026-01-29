package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port              int
	Environment       string
	DBHost            string
	DBPort            int
	DBUser            string
	DBPassword        string
	DBName            string
	SupabaseJWTSecret string
}

func Load() *Config {
	return &Config{
		Port:              getEnvInt("PORT", 8005),
		Environment:       getEnv("ENVIRONMENT", "development"),
		DBHost:            getEnv("DB_HOST", "localhost"),
		DBPort:            getEnvInt("DB_PORT", 5432),
		DBUser:            getEnv("DB_USER", "andexadmin"),
		DBPassword:        getEnv("DB_PASSWORD", "andexevents"),
		DBName:            getEnv("DB_NAME", "andexevents"),
		SupabaseJWTSecret: getEnv("SUPABASE_JWT_SECRET", ""),
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
