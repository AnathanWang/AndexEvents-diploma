# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /src

# Cache deps (need shared present because go.mod uses `replace ../../shared`)
COPY services/upload-service/go.mod services/upload-service/go.sum ./services/upload-service/
COPY shared/go.mod shared/go.sum ./shared/
WORKDIR /src/services/upload-service
RUN go mod download

# Copy source
COPY services/upload-service ./
COPY shared /src/shared

RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/upload-service ./cmd/main.go

# Runtime stage
FROM alpine:3.20

RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 8006

COPY --from=builder /bin/upload-service /bin/upload-service

ENTRYPOINT ["/bin/upload-service"]
