# 2. Структура репозитория

Ниже — ориентир по **верхнему уровню** и ключевым поддеревьям. Точный состав файлов может меняться; при расхождении приоритет у кода.

## 2.1 Корень монорепозитория

| Путь | Назначение |
|------|------------|
| `lib/` | Исходный код Flutter-приложения |
| `android/`, `ios/` | Нативные проекты, Gradle/Xcode, Firebase конфиги (`google-services.json`, `GoogleService-Info.plist`) |
| `test/`, `integration_test/` | Тесты Flutter (если присутствуют) |
| `services-java/` | Родительский Maven-проект и три Spring Boot сервиса |
| `services/` | Go-микросервисы (`match-service`, `upload-service`) |
| `shared/` | Общие Go-пакеты (например `shared/pkg/firebase`) |
| `deployments/docker/` | **`docker-compose.yml`** — основной compose для локальной инфраструктуры и приложений |
| `deployments/docker/postgres-init/` | Скрипты инициализации Postgres при первом старте контейнера |
| `secrets/` | Локальные секреты (**не коммитятся**): Firebase Admin SDK, ключи карт и т.д. |
| `scripts/` | Вспомогательные shell-скрипты (сборка, ключи Yandex и др.) |
| `docs/` | Документация проекта, включая эту папку `technical/` |
| `legacy/` | Устаревший код (в т.ч. старые Go-сервисы auth/users/events — см. `docs/changelog.md`) |

## 2.2 Flutter: `lib/`

Типичное разбиение (имена подпапок могут дополняться):

| Путь | Роль |
|------|------|
| `lib/app/` или корневые файлы приложения | Точка входа, `MaterialApp`, инъекция зависимостей |
| `lib/core/` | Конфигурация (`AppConfig`), логирование, работа с Firebase token (`IdTokenProvider` и связанные классы) |
| `lib/data/models/` | Модели данных / DTO |
| `lib/data/services/` | HTTP-клиенты к backend (`UserService`, `EventService`, …) |
| `lib/presentation/` | Экраны, виджеты, BLoC: `auth`, `home`, `events`, `profile`, `admin`, `matches`, … |

Детали конфигурации API и таймаутов: [10-flutter-client.md](./10-flutter-client.md).

## 2.3 Java backend: `services-java/`

| Путь | Роль |
|------|------|
| `pom.xml` | Родительский Maven aggregator |
| `auth-service/` | Отдельный модуль с `pom.xml`, Dockerfile, `src/main/java`, Flyway в `resources/db/migration/` |
| `users-service/` | Аналогично |
| `events-service/` | Аналогично |

## 2.4 Go backend: `services/`

| Путь | Роль |
|------|------|
| `match-service/cmd/main.go` | Точка входа, регистрация маршрутов Gin |
| `match-service/internal/` | handler, service, repository, middleware, model, config |
| `upload-service/cmd/main.go` | Точка входа upload-сервиса |
| `upload-service/internal/` | handler, storage (MinIO), repository, middleware |

## 2.5 Документация

| Путь | Роль |
|------|------|
| `docs/technical/` | Модульная техническая документация (текущая папка) |
| `docs/setup.md` | Пошаговый локальный запуск вне Docker / смешанный режим |
| `docs/api-reference.md` | Описание REST-контрактов |
| `docs/services.md` | Табличный обзор сервисов |
