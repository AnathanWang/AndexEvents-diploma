# 7. База данных и миграции

## 7.1 Экземпляр и параметры подключения

- **СУБД:** PostgreSQL **16** с расширением **PostGIS** (Docker-образ `postgis/postgis:16-3.4`).
- **Имя базы:** `andexevents`.
- **Учётные данные в локальном compose:** пользователь `andexevents`, пароль `andexevents_dev_password` (см. `deployments/docker/docker-compose.yml`).
- **Строка JDBC (Java):** `jdbc:postgresql://<host>:5432/andexevents`
- **Строка Postgres (Go):** `postgres://user:pass@host:5432/andexevents?sslmode=disable` (точный формат см. в `cmd/main.go` сервисов)

## 7.2 Стратегия изоляции: schema-per-service

В одной физической базе используются **отдельные схемы** для ограничения владения таблицами:

| Схема | Владелец миграций (типично) | Основные объекты |
|-------|-----------------------------|------------------|
| `users` | users-service (Flyway) | Таблица `"User"`, объекты из миграций (отчёты и др.) |
| `events` | events-service (Flyway) | `"Event"`, `"Participant"` |
| `auth` | auth-service (Flyway) | Служебная история / объекты без бизнес-таблицы пользователя |
| `public` | init-скрипты / расширения | `postgis` и др. |

Имена таблиц с заглавной буквы (`"User"`, `"Event"`) — следствие исторической модели и кавычек в SQL.

## 7.3 Flyway в Java-сервисах

Расположение миграций:

```
services-java/<service>/src/main/resources/db/migration/
```

Примеры файлов (могут дополняться):

- **users-service:** `V1__init.sql`, `V2__firebase_uid.sql`, `V3__add_reports.sql`
- **events-service:** `V1__init.sql`, `V2__firebase_uid.sql`
- **auth-service:** `V1__init.sql`, `V2__firebase_uid.sql`

Миграции применяются **при старте** приложения, если `FLYWAY_ENABLED=true` (для auth в вашей среде значение может отличаться — см. `docs/setup.md`).

## 7.4 Пространственные данные (PostGIS)

- Для географических запросов используются типы и функции PostGIS (например geography/point, `ST_DWithin`, `ST_MakePoint`).
- **Порядок координат в `ST_MakePoint`:** сначала **долгота (lon)**, затем **широта (lat)**.
- Индексы GiST и прочие оптимизации описаны в SQL миграций и исторических документах; актуальный состав индексов — в текущих файлах Flyway.

## 7.5 Данные матчинга

Таблицы и схема для действий матчинга обслуживаются кодом **match-service** (SQL в `internal/repository`). При изменении модели матчинга нужно синхронизировать миграции (если они вынесены в отдельный migrate-job) или SQL внутри сервиса — сверять с репозиторием.

## 7.6 Сброс данных

Опасная операция: скрипт **`scripts/wipe_db.sql`** (использование описано в `docs/setup.md`). Применять только осознанно на dev.

## 7.7 Резервное копирование и production

В production ответственность за backup, репликацию и мажорные миграции лежит на инфраструктурном контуре — см. [`../production-deployment.md`](../production-deployment.md).
