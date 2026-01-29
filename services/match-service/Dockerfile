FROM golang:1.23-alpine AS build

WORKDIR /src

COPY services/match-service/go.mod services/match-service/go.sum ./services/match-service/
WORKDIR /src/services/match-service
RUN go mod download

COPY services/match-service ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/match-service ./cmd

FROM alpine:3.20

RUN adduser -D -H -u 10001 app
USER app

WORKDIR /app
COPY --from=build /out/match-service ./match-service

EXPOSE 8005

ENTRYPOINT ["/app/match-service"]
