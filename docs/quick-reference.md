# Andex Events — краткая справка разработчика

Короткий справочник для ежедневной разработки. Полная техническая документация по модулям: **`technical/README.md`**. Подробная инструкция по локальному запуску: `setup.md`.

## Локальный запуск (минимальный)

### Инфраструктура (PostgreSQL/Redis/MinIO)

```bash
cd deployments/docker
docker compose up -d postgres redis minio
```

### Backend сервисы (вариант через Docker)

```bash
cd deployments/docker
docker compose up -d auth-service users-service events-service match-service upload-service
```

### Flutter

```bash
flutter pub get
flutter run --dart-define=YANDEX_MAPKIT_API_KEY=<your-key>
```

## Аутентификация и токены

- Клиент использует **Firebase Authentication**
- В запросах к backend передаётся заголовок `Authorization: Bearer <firebase-jwt>`

## API

- Справочник эндпойнтов: `api-reference.md`
- Все запросы выполняются через Traefik: `http://localhost/api/...`

Примеры:

```bash
curl -H "Authorization: Bearer <firebase-jwt>" http://localhost/api/auth/me
curl -H "Authorization: Bearer <firebase-jwt>" http://localhost/api/users/me
curl http://localhost/api/events
```

## PostGIS

В PostGIS порядок координат в `ST_MakePoint(lon, lat)` — сначала долгота, затем широта.

## Загрузка файлов

Загрузка изображений выполняется через `upload-service` (MinIO/S3). См. `services/docs/upload-service.md` и `api-reference.md`.

## Архитектура клиента

Ключевые принципы и структура Flutter-приложения: `architecture.md`.

## Примечание о legacy

Если в отдельных документах встречаются упоминания Supabase/Prisma/Node, это относится к историческим материалам и не является источником истины для текущей реализации.