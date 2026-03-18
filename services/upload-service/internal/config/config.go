package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port        int
	Environment string

	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	FirebaseCredentialsFile string
	FirebaseProjectID       string

	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioUseSSL    bool

	// Optional override: when running behind a gateway and you want a fixed base URL.
	UploadsPublicBaseURL string
}

func Load() *Config {
	return &Config{
		Port:        getEnvInt("PORT", 8006),
		Environment: getEnv("ENVIRONMENT", "development"),

		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnvInt("DB_PORT", 5432),
		DBUser:     getEnv("DB_USER", "andexadmin"),
		DBPassword: getEnv("DB_PASSWORD", "andexevents"),
		DBName:     getEnv("DB_NAME", "andexevents"),
		DBSSLMode:  getEnv("DB_SSL_MODE", "disable"),

		FirebaseCredentialsFile: getEnv("FIREBASE_CREDENTIALS_FILE", ""),
		FirebaseProjectID:       getEnv("FIREBASE_PROJECT_ID", ""),

		MinioEndpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
		MinioAccessKey: getEnv("MINIO_ACCESS_KEY", "andexevents"),
		MinioSecretKey: getEnv("MINIO_SECRET_KEY", "andexevents_minio_secret"),
		MinioUseSSL:    getEnvBool("MINIO_USE_SSL", false),

		UploadsPublicBaseURL: getEnv("UPLOADS_PUBLIC_BASE_URL", ""),
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

func getEnvBool(key string, defaultValue bool) bool {
	if value, exists := os.LookupEnv(key); exists {
		switch value {
		case "1", "true", "TRUE", "yes", "YES":
			return true
		case "0", "false", "FALSE", "no", "NO":
			return false
		}
	}
	return defaultValue
}
