# 4. API Gateway (Traefik)

## 4.1 Принцип работы

Traefik получает маршруты из **Docker labels** контейнеров приложений. Префикс пути на входе шлюза **совпадает** с префиксом, который ожидают приложения (они слушают полный путь `/api/...`).

Файл: `deployments/docker/docker-compose.yml`.

## 4.2 Таблица маршрутизации

Traefik router rule → сервис → port контейнера:

| Router (rule) | Контейнер | Порт приложения внутри контейнера |
|---------------|-----------|-----------------------------------|
| `PathPrefix(\`/api/users\`)` | `andexevents-users-service` | 8081 |
| `PathPrefix(\`/api/events\`)` | `andexevents-events-service` | 8082 |
| `PathPrefix(\`/api/auth\`)` | `andexevents-auth-service` | 8083 |
| `PathPrefix(\`/api/matches\`)` | `andexevents-match-service` | 8005 |
| `PathPrefix(\`/api/upload\`) \|\| PathPrefix(\`/uploads\`)` | `andexevents-upload-service` | 8006 |

Labels (пример для users-service):

- `traefik.enable=true`
- `traefik.http.routers.users.rule=PathPrefix(\`/api/users\`)`
- `traefik.http.services.users.loadbalancer.server.port=8081`

## 4.3 Базовый URL для клиента Flutter

Клиент формирует базовый URL в **`lib/core/config/app_config.dart`** (`AppConfig.baseUrl`):

| Режим / платформа | Поведение при отсутствии `API_BASE_URL` |
|-------------------|----------------------------------------|
| Переопределение | Если задан `--dart-define=API_BASE_URL=...`, используется он целиком |
| Release | `https://api.andexevents.com/api` |
| Web (debug) | `<scheme>://<Uri.base.host>/api` |
| Android (debug) | `http://10.0.2.2/api` (эмулятор → хост) |
| iOS / macOS (debug) | `http://localhost/api` |

**Важно:** при работе через Traefik локально шлюз слушает порт **80**. На физическом телефоне `localhost` указывает на сам телефон — нужно подставить IP машины в той же Wi‑Fi сети или задать `API_BASE_URL`, например `http://192.168.1.10/api`.

## 4.4 Заголовки прокси

Upload-service при сборке публичного URL учитывает **`X-Forwarded-Proto`** и **`X-Forwarded-Host`**, если `UPLOADS_PUBLIC_BASE_URL` пустой — см. [09-object-storage-uploads.md](./09-object-storage-uploads.md).

## 4.5 Согласование с документацией API

Полный перечень эндпойнтов и примеры тел поддерживаются в **`docs/api-reference.md`**. При добавлении нового сервиса или префикса необходимо:

1. Добавить сервис в `docker-compose.yml` с корректными Traefik labels  
2. Обновить `docs/api-reference.md`  
3. При необходимости обновить этот раздел и [06-backend-go.md](./06-backend-go.md) / [05-backend-java.md](./05-backend-java.md)
