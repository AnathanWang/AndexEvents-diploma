# Security hardening (диплом / prod-minimum)

Этот документ описывает минимальные улучшения безопасности, которые мы внесли, и как правильно запускать проект в dev/prod режиме.

## Что было исправлено

- **Отключили Basic Auth** в Spring Security, чтобы не появлялся "generated security password", и чтобы не было лишней auth‑поверхности.
- **Сделали безопасный режим авторизации** для Java‑сервисов: `defaultRequireAuth`.
  - В dev по умолчанию поведение старое (guard только на `requiredPaths`).
  - В prod можно включить `defaultRequireAuth=true` и тогда **любой путь**, который не является public, требует Bearer token.
- **CORS** вынесен в конфиг `app.cors.allowedOriginPatterns` (через env `APP_CORS_ALLOWEDORIGINPATTERNS`).
- **MinIO**: убрали автоматическую установку `anonymous download` для бакетов в dev-compose (чтобы не закреплять публичность по умолчанию).
- **Добавлен `docker-compose.prod.yml`**: наружу открыт только Traefik `:80`, остальные сервисы не публикуют порты.

## Как запускать

### Dev (локальная разработка)

```bash
docker compose up -d --build
```

Dev‑режим оставляет старую модель `requiredPaths` (чтобы было проще разрабатывать).

### Prod (VPS / демонстрация преподавателю)

1) Заполнить переменные окружения (минимум):
- `POSTGRES_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `FIREBASE_PROJECT_ID` (+ `FIREBASE_JWKS_URL`, если нужно)
- `CORS_ALLOWED_ORIGIN_PATTERNS` (домены, откуда будет ходить фронт)

2) Запустить:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

В `docker-compose.prod.yml` включён строгий режим:
- `APP_AUTH_DEFAULTREQUIREAUTH=true`

## Что ещё нужно для реального продакшена (необязательно для диплома)

- HTTPS (TLS) на Traefik (Let’s Encrypt) + домен.
- Ограничить/отключить Swagger в проде.
- Бэкапы Postgres + мониторинг.
- Подписанные URL для скачивания файлов вместо публичных `/uploads/*` (если появятся приватные файлы).

