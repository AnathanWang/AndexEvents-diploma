# 12. Сборка, тесты, деплой

## 12.1 Flutter

```bash
flutter pub get
flutter analyze
flutter test
```

Сборка релиза платформо-специфична (`flutter build apk`, `flutter build ipa`, и т.д.). Проект может включать скрипты в **`scripts/build-production.sh`** — см. корень репозитория и **`DEPLOYMENT_CHECKLIST.md`**.

## 12.2 Java (Maven)

Из каталога `services-java/`:

```bash
./mvnw clean package
./mvnw test
```

Dockerfile каждого сервиса собирает образ из контекста `services-java/` (см. compose).

## 12.3 Go

```bash
cd services/match-service && go test ./... && go build -o match-service ./cmd/main.go
cd services/upload-service && go test ./... && go build -o upload-service ./cmd/main.go
```

## 12.4 Docker Compose (полный стенд)

Из `deployments/docker/`:

```bash
docker compose up -d postgres redis minio
docker compose up -d traefik auth-service users-service events-service match-service upload-service
```

Требуется наличие **`secrets/firebase-service-account.json`** на хосте для Go-сервисов.

## 12.5 Makefile

В корне или в deployment-каталоге может быть `Makefile` с целями `build-java`, `build-go`, `up`, `down` — актуальный список см. в файле Makefile репозитория.

## 12.6 Production

- **`docs/production-deployment.md`** — процедуры развёртывания backend/infra.
- **`DEPLOYMENT_CHECKLIST.md`** — чеклист перед релизом мобильного приложения (подпись, ключи, store listing).

## 12.7 CI

Наличие и содержание workflow GitHub Actions — см. каталог **`.github/workflows/`** (если присутствует в ветке).
