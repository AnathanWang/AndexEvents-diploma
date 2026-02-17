.PHONY: all help build run test lint docker-up docker-down clean

all: help

help:
	@echo "AndexEvents Microservices (Java + Go)"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Development:"
	@echo "  dev-up        Start infrastructure (postgres, minio, redis, traefik)"
	@echo "  dev-down      Stop infrastructure"
	@echo "  run-match     Run match-service locally (Go)"
	@echo "  run-upload    Run upload-service locally (Go)"
	@echo ""
	@echo "Building:"
	@echo "  build-go      Build Go services (match, upload)"
	@echo "  build-java    Build Java services (auth, users, events)"
	@echo ""
	@echo "Testing:"
	@echo "  test          Run all tests"
	@echo "  test-go       Run Go tests"
	@echo "  test-java     Run Java tests"
	@echo ""
	@echo "Docker:"
	@echo "  docker-up     Start all services"
	@echo "  docker-down   Stop all services"
	@echo "  docker-build  Build Docker images"
	@echo "  docker-logs   View logs"

GO := go
DOCKER_COMPOSE := docker compose

dev-up:
	@echo "Starting infrastructure..."
	$(DOCKER_COMPOSE) up -d postgres minio minio-init redis traefik
	@sleep 5
	@echo "Ready! PostgreSQL:5432 MinIO:9000 Redis:6379 Traefik:80"

dev-down:
	$(DOCKER_COMPOSE) down

build-go:
	cd services/match-service && $(GO) build -o ../../bin/match-service ./cmd/main.go
	cd services/upload-service && $(GO) build -o ../../bin/upload-service ./cmd/main.go

build-java:
	cd services-java && ./mvnw clean package -DskipTests

run-match:
	cd services/match-service && $(GO) run ./cmd/main.go

run-upload:
	cd services/upload-service && $(GO) run ./cmd/main.go

test: test-go test-java

test-go:
	cd shared && $(GO) test -v ./...
	cd services/match-service && $(GO) test -v ./...
	cd services/upload-service && $(GO) test -v ./...

test-java:
	cd services-java && ./mvnw test

docker-up:
	$(DOCKER_COMPOSE) up -d

docker-down:
	$(DOCKER_COMPOSE) down

docker-build:
	$(DOCKER_COMPOSE) build

docker-logs:
	$(DOCKER_COMPOSE) logs -f

docker-clean:
	$(DOCKER_COMPOSE) down -v --remove-orphans

lint:
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	cd shared && golangci-lint run ./...
	cd services/match-service && golangci-lint run ./...
	cd services/upload-service && golangci-lint run ./...

fmt:
	cd shared && $(GO) fmt ./...
	cd services/match-service && $(GO) fmt ./...
	cd services/upload-service && $(GO) fmt ./...

tidy:
	cd shared && $(GO) mod tidy
	cd services/match-service && $(GO) mod tidy
	cd services/upload-service && $(GO) mod tidy

clean:
	rm -rf bin/
	rm -rf services/*/coverage.out services/*/coverage.html

.DEFAULT_GOAL := help
