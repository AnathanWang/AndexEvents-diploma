.PHONY: all help build run test lint migrate docker-up docker-down clean

# Default target
all: help

# ============================================
# HELP
# ============================================

help:
	@echo "AndexEvents Hybrid Microservices (Java/Go)"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Development (Infrastructure):"
	@echo "  dev-up        Start development infrastructure (postgres, minio, redis)"
	@echo "  dev-down      Stop development infrastructure"
	@echo ""
	@echo "Go Services (Active):"
	@echo "  run-match     Run match-service locally (Go)"
	@echo "  run-upload    Run upload-service locally (Go)"
	@echo "  build-match   Build match-service"
	@echo "  build-upload  Build upload-service"
	@echo ""
	@echo "Docker:"
	@echo "  docker-up     Start all services (Java+Go) in Docker"
	@echo "  docker-down   Stop all services"
	@echo "  docker-build  Build Docker images"
	@echo "  docker-logs   View logs from all services"
	@echo ""

# ============================================
# VARIABLES
# ============================================

GO := go
# Using the hybrid docker-compose file
DOCKER_COMPOSE := docker compose -f deployments/docker/docker-compose.hybrid.yml

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

build: build-match build-upload

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
	@echo "Running active service tests..."
	cd shared && $(GO) test -v ./...
	cd services/match-service && $(GO) test -v ./...
	cd services/upload-service && $(GO) test -v ./...

test-match:
	@echo "Running match-service tests..."
	cd services/match-service && $(GO) test -v ./...

test-upload:
	@echo "Running upload-service tests..."
	cd services/upload-service && $(GO) test -v ./...

# ============================================
# DOCKER
# ============================================

docker-up:
	@echo "Starting all services in Docker (Hybrid)..."
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
	# Add active services here
	cd services/match-service && golangci-lint run ./...
	cd services/upload-service && golangci-lint run ./...

fmt:
	@echo "Formatting Go code..."
	cd shared && $(GO) fmt ./...
	cd services/match-service && $(GO) fmt ./...
	cd services/upload-service && $(GO) fmt ./...

tidy:
	@echo "Running go mod tidy..."
	cd shared && $(GO) mod tidy
	cd services/match-service && $(GO) mod tidy
	cd services/upload-service && $(GO) mod tidy

clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/

.DEFAULT_GOAL := help
