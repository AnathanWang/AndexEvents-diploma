FROM golang:1.24-alpine AS build

WORKDIR /src

COPY services/events-service/go.mod services/events-service/go.sum ./services/events-service/
WORKDIR /src/services/events-service
RUN go mod download

COPY services/events-service ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/events-service ./cmd

FROM alpine:3.20

RUN adduser -D -H -u 10001 app
USER app

WORKDIR /app
COPY --from=build /out/events-service ./events-service

EXPOSE 8002

ENTRYPOINT ["/app/events-service"]
