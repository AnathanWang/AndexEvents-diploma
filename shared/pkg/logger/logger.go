// Package logger предоставляет структурированное логирование на базе Zap.
//
// Zap - это высокопроизводительный логгер от Uber.
// Почему Zap, а не стандартный log?
// 1. Структурированные логи (JSON) - легко парсить в ELK/Grafana
// 2. Уровни логирования (Debug, Info, Warn, Error)
// 3. Производительность - минимум аллокаций
// 4. Контекстные поля - можно добавлять metadata к логам
package logger

import (
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var log *zap.Logger

// Config конфигурация логгера
type Config struct {
	Level       string // debug, info, warn, error
	Environment string // development, production
	ServiceName string
}

// Init инициализирует глобальный логгер
func Init(cfg Config) error {
	var config zap.Config

	if cfg.Environment == "production" {
		// Production: JSON формат, без стектрейсов для info
		config = zap.NewProductionConfig()
		config.EncoderConfig.TimeKey = "timestamp"
		config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	} else {
		// Development: человекочитаемый формат с цветами
		config = zap.NewDevelopmentConfig()
		config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	}

	// Устанавливаем уровень логирования
	switch cfg.Level {
	case "debug":
		config.Level = zap.NewAtomicLevelAt(zap.DebugLevel)
	case "info":
		config.Level = zap.NewAtomicLevelAt(zap.InfoLevel)
	case "warn":
		config.Level = zap.NewAtomicLevelAt(zap.WarnLevel)
	case "error":
		config.Level = zap.NewAtomicLevelAt(zap.ErrorLevel)
	default:
		config.Level = zap.NewAtomicLevelAt(zap.InfoLevel)
	}

	var err error
	log, err = config.Build(
		zap.AddCallerSkip(1), // Пропускаем этот пакет в стектрейсе
		zap.Fields(zap.String("service", cfg.ServiceName)),
	)
	if err != nil {
		return err
	}

	return nil
}

// Sync сбрасывает буфер логов - вызывать при завершении программы
func Sync() {
	if log != nil {
		_ = log.Sync()
	}
}

// Debug логирует сообщение уровня debug
func Debug(msg string, fields ...zap.Field) {
	if log == nil {
		initDefault()
	}
	log.Debug(msg, fields...)
}

// Info логирует сообщение уровня info
func Info(msg string, fields ...zap.Field) {
	if log == nil {
		initDefault()
	}
	log.Info(msg, fields...)
}

// Warn логирует сообщение уровня warn
func Warn(msg string, fields ...zap.Field) {
	if log == nil {
		initDefault()
	}
	log.Warn(msg, fields...)
}

// Error логирует сообщение уровня error
func Error(msg string, fields ...zap.Field) {
	if log == nil {
		initDefault()
	}
	log.Error(msg, fields...)
}

// Fatal логирует сообщение и завершает программу
func Fatal(msg string, fields ...zap.Field) {
	if log == nil {
		initDefault()
	}
	log.Fatal(msg, fields...)
}

// With создаёт логгер с дополнительными полями
func With(fields ...zap.Field) *zap.Logger {
	if log == nil {
		initDefault()
	}
	return log.With(fields...)
}

// initDefault создаёт дефолтный логгер если Init не был вызван
func initDefault() {
	cfg := zap.NewDevelopmentConfig()
	cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	var err error
	log, err = cfg.Build(zap.AddCallerSkip(1))
	if err != nil {
		// Fallback на стандартный вывод
		log = zap.NewExample()
	}
}

// GetLogger возвращает базовый zap.Logger для продвинутого использования
func GetLogger() *zap.Logger {
	if log == nil {
		initDefault()
	}
	return log
}

// NewNop создаёт no-op логгер (для тестов)
func NewNop() *zap.Logger {
	return zap.NewNop()
}

// FromEnv создаёт конфиг из переменных окружения
func FromEnv(serviceName string) Config {
	env := os.Getenv("ENVIRONMENT")
	if env == "" {
		env = "development"
	}
	level := os.Getenv("LOG_LEVEL")
	if level == "" {
		level = "debug"
	}
	return Config{
		Level:       level,
		Environment: env,
		ServiceName: serviceName,
	}
}
