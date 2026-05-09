# Техническая документация Andex Events

Модульное описание **фактической** реализации монорепозитория: Flutter-клиент, микросервисы на Java (Spring Boot) и Go (Gin), PostgreSQL + PostGIS, MinIO, Traefik.

**Рекомендуемый порядок чтения**

| № | Файл | Содержание |
|---|------|------------|
| 1 | [01-overview.md](./01-overview.md) | Назначение системы, архитектура, стек технологий |
| 2 | [02-repository-structure.md](./02-repository-structure.md) | Структура каталогов репозитория |
| 3 | [03-infrastructure-and-docker.md](./03-infrastructure-and-docker.md) | Docker Compose: Postgres, MinIO, Redis, переменные, порты |
| 4 | [04-api-gateway-traefik.md](./04-api-gateway-traefik.md) | Маршрутизация Traefik, базовый URL для клиента |
| 5 | [05-backend-java.md](./05-backend-java.md) | auth-, users-, events-service (Spring Boot, Flyway, JDBC) |
| 6 | [06-backend-go.md](./06-backend-go.md) | match-service и upload-service (Gin, конфиг, маршруты, тела запросов) |
| 7 | [07-database-and-migrations.md](./07-database-and-migrations.md) | Схемы БД, миграции, PostGIS |
| 8 | [08-authentication-firebase.md](./08-authentication-firebase.md) | Firebase ID Token, JWKS (Java), сервисный аккаунт (Go) |
| 9 | [09-object-storage-uploads.md](./09-object-storage-uploads.md) | MinIO, бакеты, загрузка, публичные URL |
| 10 | [10-flutter-client.md](./10-flutter-client.md) | Слои приложения, AppConfig, сеть |
| 11 | [11-security-and-secrets.md](./11-security-and-secrets.md) | Секреты, заголовки, публичные эндпойнты |
| 12 | [12-build-tests-deployment.md](./12-build-tests-deployment.md) | Сборка, тесты, ссылки на production |
| 13 | [13-legacy-and-other-docs.md](./13-legacy-and-other-docs.md) | Устаревшие документы в `docs/`, что считать источником истины |

**Быстрые ссылки вне этой папки**

- Локальный запуск и таблицы переменных окружения (в т.ч. для запуска без Docker): [`../setup.md`](../setup.md)
- Справочник HTTP API (эволюционирует вместе с кодом): [`../api-reference.md`](../api-reference.md)
- Краткий обзор сервисов: [`../services.md`](../services.md)
