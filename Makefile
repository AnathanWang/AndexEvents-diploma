.PHONY: all help build run test lint migrate docker-up docker-down clean

# Default target
all: help

# ============================================
# HELP
# ============================================

help:
	@echo "AndexEvents Go Microservices"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Development:"
	@echo "  dev-up        Start development infrastructure (postgres, minio, redis)"
	@echo "  dev-down      Stop development infrastructure"
	@echo "  run-auth      Run auth-service locally"
	@echo "  run-events    Run events-service locally"
	@echo "  run-match     Run match-service locally"
	@echo "  run-upload    Run upload-service locally"
	@echo ""
	@echo "Building:"
	@echo "  build         Build all services"
	@echo "  build-auth    Build auth-service"
	@echo "  build-events  Build events-service"
	@echo "  build-match   Build match-service"
	@echo "  build-upload  Build upload-service"
	@echo ""
	@echo "Testing:"
	@echo "  test          Run all tests"
	@echo "  test-auth     Run auth-service tests"
	@echo "  test-events   Run events-service tests"
	@echo "  test-match    Run match-service tests"
	@echo "  test-upload   Run upload-service tests"
	@echo "  coverage      Run tests with coverage"
	@echo ""
	@echo "Database:"
	@echo "  migrate-up    Run all migrations"
	@echo "  migrate-down  Rollback all migrations"
	@echo "  migrate-auth-up     Run auth-service migrations"
	@echo "  migrate-auth-down   Rollback auth-service migrations"
	@echo ""
	@echo "Docker:"
	@echo "  docker-up     Start all services in Docker"
	@echo "  docker-down   Stop all services"
	@echo "  docker-build  Build Docker images"
	@echo "  docker-logs   View logs from all services"
	@echo ""
	@echo "Utilities:"
	@echo "  lint          Run linter on all code"
	@echo "  fmt           Format all Go code"
	@echo "  tidy          Run go mod tidy on all modules"
	@echo "  clean         Clean build artifacts"
	@echo "  proto         Generate protobuf code (if needed)"

# ============================================
# VARIABLES
# ============================================

GO := go
DOCKER_COMPOSE := docker compose -f deployments/docker/docker-compose.yml
MIGRATE := migrate

# Database connection
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= andexevents
DB_PASSWORD ?= andexevents_dev_password
DB_NAME ?= andexevents
DB_URL := postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable

# ============================================
# DEVELOPMENT INFRASTRUCTURE
# ============================================

dev-up:
	@echo "Starting development infrastructure..."
	$(DOCKER_COMPOSE) up -d postgres minio minio-init redis
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Infrastructure is ready!"
	@echo "  PostgreSQL: localhost:5432"
	@echo "  MinIO S3: localhost:9000"
	@echo "  MinIO Console: localhost:9001"
	@echo "  Redis: localhost:6379"

dev-down:
	@echo "Stopping development infrastructure..."
	$(DOCKER_COMPOSE) down

# ============================================
# BUILD
# ============================================

build: build-auth build-events build-match build-upload

build-auth:
	@echo "Building auth-service..."
	cd services/auth-service && $(GO) build -o ../../bin/auth-service ./cmd/main.go

build-events:
	@echo "Building events-service..."
	@if [ -f services/events-service/cmd/main.go ]; then \
		cd services/events-service && $(GO) build -o ../../bin/events-service ./cmd/main.go; \
	else \
		echo "events-service not implemented yet"; \
	fi

build-match:
	@echo "Building match-service..."
	@if [ -f services/match-service/cmd/main.go ]; then \
		cd services/match-service && $(GO) build -o ../../bin/match-service ./cmd/main.go; \
	else \
		echo "match-service not implemented yet"; \
	fi

build-upload:
	@echo "Building upload-service..."
	@if [ -f services/upload-service/cmd/main.go ]; then \
		cd services/upload-service && $(GO) build -o ../../bin/upload-service ./cmd/main.go; \
	else \
		echo "upload-service not implemented yet"; \
	fi

# ============================================
# RUN LOCALLY
# ============================================

run-auth:
	@echo "Running auth-service..."
	cd services/auth-service && $(GO) run ./cmd/main.go

run-events:
	@echo "Running events-service..."
	cd services/events-service && $(GO) run ./cmd/main.go

run-match:
	@echo "Running match-service..."
	cd services/match-service && $(GO) run ./cmd/main.go

run-upload:
	@echo "Running upload-service..."
	cd services/upload-service && $(GO) run ./cmd/main.go

# ============================================
# TESTING
# ============================================

test:
	@echo "Running all tests..."
	cd shared && $(GO) test -v ./...
	cd services/auth-service && $(GO) test -v ./...

test-auth:
	@echo "Running auth-service tests..."
	cd services/auth-service && $(GO) test -v ./...

test-events:
	@echo "Running events-service tests..."
	cd services/events-service && $(GO) test -v ./...

test-match:
	@echo "Running match-service tests..."
	cd services/match-service && $(GO) test -v ./...

test-upload:
	@echo "Running upload-service tests..."
	cd services/upload-service && $(GO) test -v ./...

coverage:
	@echo "Running tests with coverage..."
	cd services/auth-service && $(GO) test -coverprofile=coverage.out ./...
	cd services/auth-service && $(GO) tool cover -html=coverage.out -o coverage.html

# ============================================
# DATABASE MIGRATIONS
# ============================================

migrate-up: migrate-auth-up
	@echo "All migrations completed!"

migrate-down: migrate-auth-down
	@echo "All migrations rolled back!"

migrate-auth-up:
	@echo "Running auth-service migrations..."
	$(MIGRATE) -path services/auth-service/migrations -database "$(DB_URL)" up

migrate-auth-down:
	@echo "Rolling back auth-service migrations..."
	$(MIGRATE) -path services/auth-service/migrations -database "$(DB_URL)" down

migrate-create:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make migrate-create name=<migration_name> service=<service_name>"; \
		exit 1; \
	fi
	@if [ -z "$(service)" ]; then \
		echo "Usage: make migrate-create name=<migration_name> service=<service_name>"; \
		exit 1; \
	fi
	$(MIGRATE) create -ext sql -dir services/$(service)/migrations -seq $(name)

# ============================================
# DOCKER
# ============================================

docker-up:
	@echo "Starting all services in Docker..."
	$(DOCKER_COMPOSE) up -d

docker-down:
	@echo "Stopping all services..."
	$(DOCKER_COMPOSE) down

docker-build:
	@echo "Building Docker images..."
	$(DOCKER_COMPOSE) build

docker-logs:
	$(DOCKER_COMPOSE) logs -f

docker-clean:
	@echo "Removing all containers and volumes..."
	$(DOCKER_COMPOSE) down -v --remove-orphans

# ============================================
# UTILITIES
# ============================================

lint:
	@echo "Running linter..."
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	cd shared && golangci-lint run ./...
	cd services/auth-service && golangci-lint run ./...

fmt:
	@echo "Formatting Go code..."
	cd shared && $(GO) fmt ./...
	cd services/auth-service && $(GO) fmt ./...

tidy:
	@echo "Running go mod tidy..."
	cd shared && $(GO) mod tidy
	cd services/auth-service && $(GO) mod tidy

clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	rm -rf services/*/coverage.out
	rm -rf services/*/coverage.html

# ============================================
# SETUP
# ============================================

setup: install-tools dev-up migrate-up
	@echo "Development environment is ready!"

install-tools:
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@echo "Tools installed!"

.DEFAULT_GOAL := help
