// Package database предоставляет пул подключений к PostgreSQL.
//
// Почему pgx, а не database/sql?
// 1. Нативная поддержка PostgreSQL типов (UUID, JSONB, arrays)
// 2. Лучшая производительность (меньше копирований)
// 3. Batch запросы
// 4. Поддержка COPY для bulk операций
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Config конфигурация подключения к БД
type Config struct {
	Host     string
	Port     int
	User     string
	Password string
	Database string
	SSLMode  string

	// Pool settings
	MaxConns          int           // Максимум подключений в пуле
	MinConns          int           // Минимум подключений
	MaxConnLifetime   time.Duration // Время жизни подключения
	MaxConnIdleTime   time.Duration // Время простоя до закрытия
	HealthCheckPeriod time.Duration // Период проверки здоровья
}

// DefaultConfig возвращает конфиг по умолчанию
func DefaultConfig() Config {
	return Config{
		Host:              "localhost",
		Port:              5432,
		User:              "andexadmin",
		Password:          "andexevents",
		Database:          "andexevents",
		SSLMode:           "disable",
		MaxConns:          25,
		MinConns:          5,
		MaxConnLifetime:   time.Hour,
		MaxConnIdleTime:   30 * time.Minute,
		HealthCheckPeriod: time.Minute,
	}
}

// NewPool создаёт пул подключений к PostgreSQL
func NewPool(ctx context.Context, cfg Config) (*pgxpool.Pool, error) {
	// Формируем DSN (Data Source Name)
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.User,
		cfg.Password,
		cfg.Host,
		cfg.Port,
		cfg.Database,
		cfg.SSLMode,
	)

	// Парсим конфиг
	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	// Настраиваем пул
	if cfg.MaxConns > 0 {
		poolConfig.MaxConns = int32(cfg.MaxConns)
	}
	if cfg.MinConns > 0 {
		poolConfig.MinConns = int32(cfg.MinConns)
	}
	if cfg.MaxConnLifetime > 0 {
		poolConfig.MaxConnLifetime = cfg.MaxConnLifetime
	}
	if cfg.MaxConnIdleTime > 0 {
		poolConfig.MaxConnIdleTime = cfg.MaxConnIdleTime
	}
	if cfg.HealthCheckPeriod > 0 {
		poolConfig.HealthCheckPeriod = cfg.HealthCheckPeriod
	}

	// Создаём пул
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create pool: %w", err)
	}

	// Проверяем подключение
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return pool, nil
}
