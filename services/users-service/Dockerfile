FROM golang:1.24-alpine AS build

WORKDIR /src

COPY services/users-service/go.mod services/users-service/go.sum ./services/users-service/
WORKDIR /src/services/users-service
RUN go mod download

COPY services/users-service ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/users-service ./cmd

FROM alpine:3.20

RUN adduser -D -H -u 10001 app
USER app

WORKDIR /app
COPY --from=build /out/users-service ./users-service

EXPOSE 8003

ENTRYPOINT ["/app/users-service"]
