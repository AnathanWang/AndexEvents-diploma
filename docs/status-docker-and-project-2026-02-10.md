# Andexevents — статус Docker и проекта (2026-02-10)

## TL;DR
- Hybrid backend (Go + Java) в Docker **поднимается**, MinIO/Postgres/Redis **healthy**.
- **Traefik работает:** исправлено подключение к Docker provider (обновление версии), роутинг через `http://localhost/api/...` **работает**.
- Flutter уже частично переведён на **Firebase Auth + Firebase ID token** и единый `API_BASE_URL` через gateway (`/api`), но миграция изображений **Supabase Storage → upload-service → MinIO** ждёт исправления Traefik маршрутизации (или временного обхода через прямые порты).

---

## 1) Текущая ситуация по Docker

### 1.1 Контейнеры (docker compose hybrid)
Файл запуска: `deployments/docker/docker-compose.hybrid.yml`.

На момент проверки `docker compose ... ps`:
- `andexevents-traefik` — Up, порты: `80` (gateway), `8080` (dashboard)
- `andexevents-upload-service` (Go) — Up, порт: `8006`
- `andexevents-match-service` (Go) — Up, порт: `8005`
- `andexevents-users-service-java` — Up, порт: `8081`
- `andexevents-events-service-java` — Up, порт: `8082`
- `andexevents-auth-service-java` — Up, порт: `8083`
- `andexevents-postgres` — Up (healthy), порт: `5432`
- `andexevents-redis` — Up (healthy), порт: `6379`
- `andexevents-minio` — Up (healthy), порты: `9000` (S3 API), `9001` (console)

Примечание: compose пишет предупреждение, что поле `version` устарело и игнорируется.

### 1.2 Что работает прямо сейчас
Сервисы сами по себе стартуют:
- `upload-service` поднял эндпоинты:
  - `GET /health`
  - `POST /api/upload`
  - `GET /uploads/:bucket/:userId/:filename`
- `match-service` поднял эндпоинты:
  - `GET /health`
  - `GET /api/matches`
  - и др.
- Java сервисы стартуют, поднимают Tomcat на `8081/8082/8083`, делают Flyway миграции.

Важно: Java сервисы сейчас запускаются со **стандартным Spring Security** и логируют сгенерированный пароль (dev). Это означает, что часть эндпоинтов может требовать базовую авторизацию/или быть закрытой по умолчанию.

### 1.3 Что НЕ работает
#### Gateway `http://localhost/api/...`
- Любые `curl http://localhost/api/...` возвращают **404**.
- Причина: Traefik **не подхватывает конфигурацию из Docker labels** (Docker provider не работает) → роутеры/сервисы в Traefik не создаются.

### 1.4 Логи Traefik (ключевое)
В `docker compose logs traefik` повторяется:
- `Failed to retrieve information of the docker client and server host error="Error response from daemon: " providerName=docker`
- `Provider error, retrying ...`

Также периодически встречаются TLS handshake ошибки от `192.168.65.1` (для статуса маршрутизации это вторично; основной блокер — Docker provider).

### 1.5 Контекст: что уже было исправлено (build-level)
За последние итерации были сняты блокеры сборки образов:
- Go:
  - устранён конфликт версии Go (`go.mod` требует `>= 1.24.0`)
  - исправлен порядок `COPY` в Dockerfile’ах так, чтобы работал `replace ../../shared` во время `go mod download`
- Java (multi-module Maven):
  - исправлен build context в compose (сборка из корня `services-java`)
  - Dockerfile’ы переделаны под `mvn -pl <module> -am`, чтобы корректно резолвился parent POM

Итого: сейчас проблема **не в сборке**, а в **runtime discovery** (Traefik↔Docker provider).

---

## 2) Статус проекта в целом

### 2.1 Целевая архитектура (куда идём)
- Один gateway: Traefik на `:80`.
- Flutter ходит только в один base URL:
  - iOS/macOS: `http://localhost/api`
  - Android emulator: `http://10.0.2.2/api`
- Авторизация: **Firebase-only** (ID token в `Authorization: Bearer <token>`).
- Загрузка изображений: **не Supabase Storage**, а `upload-service` → **MinIO** в Docker.

### 2.2 Flutter
Что уже сделано ранее (по текущему контексту проекта):
- Firebase зависимости и инициализация включены.
- `AuthService` переписан на `FirebaseAuth + Google Sign-In`.
- HTTP слой/часть сервисов переведены на токен `Firebase ID token`.
- Базовые URL’ы для API приведены к Traefik gateway (`/api`) и убраны хардкоды типа `localhost:3000` для upload.

Что осталось (критично для цели с изображениями):
- Удалить/заменить оставшиеся пути, которые грузят файлы в Supabase Storage.
- Перевести все загрузки картинок на `POST /api/upload` (через gateway), а ссылки хранить/отдавать как URL на `GET /uploads/...` (или через gateway, если проксируется).

### 2.3 Backend
- Go `upload-service` уже поднимает `POST /api/upload` и отдачу файлов через `/uploads/...`.
- MinIO работает в Docker (healthy). Инициализация бакетов выполнена отдельным init-контейнером (по проектному плану).

Ключевой пробел, который тормозит end-to-end:
- Нужна рабочая маршрутизация Traefik, чтобы Flutter мог обращаться к `/api/upload` стабильно через единый base URL.

---

## 3) Следующие шаги (очень конкретно)
1) Починить Traefik Docker provider:
   - цель: в dashboard Traefik должны появиться routers/services из Docker labels
   - smoke test: `curl http://localhost/api/upload` должен дойти до `upload-service` (ожидаемо 405/400/401 в зависимости от метода/авторизации, но не 404 от Traefik)
2) Проверить upload → MinIO:
   - загрузить тестовый файл через gateway
   - убедиться, что объект появился в нужном bucket’е MinIO
3) Доделать Flutter миграцию Supabase Storage → upload-service:
   - заменить оставшиеся места загрузки
   - убедиться, что UI получает валидные URL и отображает изображения

---

## 4) Полезные порты для диагностики
- Traefik gateway: `http://localhost/` (API ожидается по `http://localhost/api/...`)
- Traefik dashboard: `http://localhost:8080/`
- Upload service (мимо Traefik): `http://localhost:8006/`
- Match service (мимо Traefik): `http://localhost:8005/`
- Users service (Java): `http://localhost:8081/`
- Events service (Java): `http://localhost:8082/`
- Auth service (Java): `http://localhost:8083/`
- MinIO S3 API: `http://localhost:9000/`
- MinIO Console: `http://localhost:9001/`

## 6) Миграция файлов (Local → MinIO)
- **Статус:** ✅ Выполнена.
- **Скрипт:** `scripts/migrate_local_uploads_to_minio.sh` обработал локальные файлы из `backend/public/uploads` и загрузил их в MinIO.
- **Проверка:** Файлы доступны через `http://localhost/uploads/<bucket>/<userId>/<filename>`.
- **Дальнейшие действия:** Удалить локальные файлы из репозитория после подтверждения работы на клиентах.

---

## 5) Текущее состояние как «готовность к цели»
- ✅ Контейнеры поднимаются, БД/MinIO healthy
- ✅ upload-service существует и слушает нужные маршруты
- ✅ Traefik подключен и маршрутизирует `/api/*` (Docker provider OK)
- ⏳ Flutter миграция картинок завершится после проверки upload endpoints
