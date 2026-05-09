# 3. Инфраструктура и Docker Compose

Источник истины для состава контейнеров и портов в локальной связке: **`deployments/docker/docker-compose.yml`**.

## 3.1 Сеть

Все сервисы подключены к Docker-сети **`andexevents-network`** (driver `bridge`), имя контейнера используется как hostname (например `postgres`, `minio`).

## 3.2 PostgreSQL

| Параметр | Значение в compose |
|----------|-------------------|
| Образ | `postgis/postgis:16-3.4` |
| Контейнер | `andexevents-postgres` |
| Пользователь БД | `andexevents` |
| Пароль | `andexevents_dev_password` |
| Имя БД | `andexevents` |
| Порт хоста | `5432` |
| Том | `postgres_data` |
| Init | `./postgres-init` монтируется в `/docker-entrypoint-initdb.d` |

Healthcheck: `pg_isready -U andexevents -d andexevents`.

## 3.3 MinIO

| Параметр | Значение в compose |
|----------|-------------------|
| Образ | `minio/minio:latest` |
| Root user | `andexevents` |
| Root password | `andexevents_minio_secret` |
| API порт | `9000` |
| Console порт | `9001` |

Сервис **`minio-init`** (образ `minio/mc`) после готовности MinIO выполняет:

- `mc alias set local http://minio:9000 andexevents andexevents_minio_secret`
- создание бакетов: `avatars`, `events`, `photos`, `media`

**Замечание по коду upload-service:** функция `AllowedBucket` в `upload-service/internal/storage/minio.go` допускает только `avatars`, `events`, `photos`. Бакет `media` создан в compose, но загрузка в него через текущую проверку может быть отклонена — при необходимости расширить список в коде.

## 3.4 Redis

| Параметр | Значение |
|----------|----------|
| Образ | `redis:7-alpine` |
| Порт | `6379` |
| Том | `redis_data` |

Наличие Redis в compose не гарантирует, что каждый микросервис уже использует его — проверять импорты и конфигурацию в `services-java` и Go.

## 3.5 Traefik

| Параметр | Значение |
|----------|----------|
| Образ | `traefik:latest` |
| Порт | `80` (entrypoint `web`) |
| Провайдер | Docker (socket `/var/run/docker.sock`, read-only) |
| Поведение | `exposedbydefault=false` — маршруты только у контейнеров с `traefik.enable=true` |

Dashboard в аргументах **не включён** (комментарий в compose: intentionally disabled).

## 3.6 Прикладные сервисы в Compose

Общие переменные JDBC для Java (типовой фрагмент):

- `SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/andexevents`
- `SPRING_DATASOURCE_USERNAME=andexevents`
- `SPRING_DATASOURCE_PASSWORD=andexevents_dev_password`
- `FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-andexevents}`
- `FIREBASE_JWKS_URL=${FIREBASE_JWKS_URL:-}` (опционально переопределить URL JWKS)

Go-сервисы получают доступ к БД через `DB_HOST=postgres`, учётные данные как в таблице compose.

**Mount секретов для Go:** оба сервиса монтируют файл хоста  

`../../secrets/firebase-service-account.json`  

в контейнер как **`/app/firebase-credentials.json`** (read-only), переменная **`FIREBASE_CREDENTIALS_FILE=/app/firebase-credentials.json`**.

**Upload-service дополнительно:**

- `MINIO_ENDPOINT=minio:9000`
- `MINIO_ACCESS_KEY=andexevents`
- `MINIO_SECRET_KEY=andexevents_minio_secret`
- `MINIO_USE_SSL=0`
- `UPLOADS_PUBLIC_BASE_URL=${UPLOADS_PUBLIC_BASE_URL:-http://localhost}` — база для формирования публичных ссылок на файлы за шлюзом

## 3.7 Проброс портов приложений на хост

Для отладки без Traefik можно ходить напрямую:

| Сервис | Порт на хосте |
|--------|----------------|
| users-service | 8081 |
| events-service | 8082 |
| auth-service | 8083 |
| match-service | 8005 |
| upload-service | 8006 |

Через Traefik клиент использует **`http://<host>/api/...`** (порт 80).

## 3.8 Тома Compose

- `postgres_data` — данные PostgreSQL  
- `minio_data` — объекты MinIO  
- `redis_data` — данные Redis  

Полный сброс данных — удаление томов и пересоздание контейнеров (осознанная операция).
