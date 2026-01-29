# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Cache deps
COPY services/upload-service/go.mod ./
COPY services/upload-service/go.sum ./
COPY shared/go.mod ./shared/go.mod
COPY shared/go.sum ./shared/go.sum
RUN go mod download

# Copy source
COPY services/upload-service ./
COPY shared ./shared

RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/upload-service ./cmd/main.go

# Runtime stage
FROM alpine:3.20

RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 8006

COPY --from=builder /bin/upload-service /bin/upload-service

ENTRYPOINT ["/bin/upload-service"]
