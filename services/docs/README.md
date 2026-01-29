# 📚 Документация Go Микросервисов

Эта папка содержит документацию по Go микросервисам проекта AndexEvents.

## 📁 Структура документации

| Файл | Описание |
|------|----------|
| [auth-service.md](./auth-service.md) | Auth Service - аутентификация и управление пользователями |
| [match-service.md](./match-service.md) | Match Service - лайки/дизлайки и взаимные мэтчи |
| [upload-service.md](./upload-service.md) | Upload Service - загрузка изображений и публичные `/uploads/*` |
| [architecture.md](./architecture.md) | Общая архитектура микросервисов |
| [api-reference.md](./api-reference.md) | Справочник по всем API endpoints |

## 🚀 Быстрый старт

```bash
# Запуск auth-service
cd services/auth-service
FIREBASE_CREDENTIALS_FILE=../../secrets/firebase-service-account.json \
FIREBASE_PROJECT_ID=andexevents \
DB_HOST=localhost DB_PORT=5432 \
DB_USER=andexadmin DB_PASSWORD=andexevents DB_NAME=andexevents \
go run cmd/main.go
```

## 📖 Дополнительно

- Основная документация проекта: [/docs](/docs)
- План миграции на Go: [GOLANG_MIGRATION_PLAN.md](/GOLANG_MIGRATION_PLAN.md)
