# 📚 Документация backend-сервисов

Эта папка содержит документацию по backend-сервисам проекта Andex Events (часть сервисов написана на Go, часть — на Java/Spring Boot).

## 📁 Структура документации

| Файл | Описание |
|------|----------|
| [auth-service.md](./auth-service.md) | Auth service: аутентификация, валидация JWT, интеграция с Firebase |
| [users-service.md](./users-service.md) | Users service: профили пользователей, интересы, настройки, админ-операции |
| [events-service.md](./events-service.md) | Events service: события, участие, модерация, геопоиск (PostGIS) |
| [match-service.md](./match-service.md) | Match service: лайки/дизлайки, взаимные мэтчи, подборки |
| [upload-service.md](./upload-service.md) | Upload service: загрузка изображений и публичная раздача файлов |
| [architecture.md](./architecture.md) | Общая архитектура микросервисов |
| [api-reference.md](./api-reference.md) | Справочник по всем API endpoints |

## 🚀 Быстрый старт

Актуальная инструкция по локальному запуску находится в `docs/setup.md` в корне репозитория.

## 📖 Дополнительно

- Основная документация проекта: [/docs](/docs)
- План миграции на Go: [GOLANG_MIGRATION_PLAN.md](/GOLANG_MIGRATION_PLAN.md)
