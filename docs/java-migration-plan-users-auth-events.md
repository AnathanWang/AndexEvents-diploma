# План миграции `users-service`, `auth-service`, `events-service` с Go на Java (Spring Boot)

Дата: 2026-02-09

## 1) Цели
- Переписать **3 микросервиса** на Java так, чтобы внешнее API и поведение сохранились.
- Получить «пет-проект как у Java backend»: Spring Boot 3, Spring Security, JPA/QueryDSL (опционально), Flyway, интеграционные тесты с Testcontainers, наблюдаемость.
- Мигрировать **постепенно** (Strangler pattern): Go-версии продолжают работать, Java-версии вводятся по одному сервису.

## 2) Ограничения и допущения
- Инфра уже есть: Postgres/PostGIS, MinIO, Redis (см. [docker-compose.yml](../docker-compose.yml)).
- Сейчас сервисы на Go находятся в:
  - [services/users-service/](../services/users-service/)
  - [services/auth-service/](../services/auth-service/)
  - [services/events-service/](../services/events-service/)
- Предпочтительный рантайм для Java: **Java 21**.
- БД оставляем одну (контейнер `andexevents-postgres`), но разделяем владение данными по сервисам через **Postgres schemas** (рекомендация): `users`, `auth`, `events`.

## 3) Что НЕ делаем (чтобы не раздувать)
- Не переписываем остальные сервисы.
- Не меняем доменную модель и клиентские контракты без необходимости.
- Не внедряем сложную сервис-меш/кафку, если это не требуется текущей архитектурой.

## 4) Целевой стек для Java
- **Spring Boot 3.x**: `spring-boot-starter-web`, `actuator`, `validation`
- **Data**: `spring-boot-starter-data-jpa` + Postgres драйвер
- **Migrations**: Flyway
- **Security** (auth-service): `spring-boot-starter-security` + JWT
- **Docs**: `springdoc-openapi`
- **Testing**: JUnit 5, Testcontainers (Postgres), RestAssured/WebTestClient
- **Observability**: Actuator + structured logs (logback JSON опционально)

## 5) Стратегия миграции (Strangler)
### 5.1. Базовый принцип
1) Фиксируем контракт и поведение Go-сервиса.
2) Поднимаем Java-версию рядом (другой порт/другой сервис в compose).
3) Включаем зеркалирование/сравнение (по возможности) и прогоняем тесты.
4) Переключаем трафик на Java (с возможностью отката).

### 5.2. Где переключать трафик
Выбрать один способ (любой из них норм):
- **Reverse proxy** (Traefik/Nginx): роутинг `/api/users` → Java users-service.
- **BFF/Gateway** (если есть единая точка входа): прокинуть вызовы на Java вместо Go.

## 6) Подготовительный этап (1–2 дня)
### 6.1. Инвентаризация API
Для каждого Go-сервиса собрать:
- список эндпоинтов, методы, коды ответов, ошибки
- форматы DTO (request/response)
- правила валидации, пагинация/сортировка
- авторизация: какие хедеры/токены ожидаются
- зависимости: Postgres, Redis, MinIO, внешние API

Практика: зафиксировать контракт в `openapi.yaml` (минимум — вручную), либо сгенерировать из Go.

### 6.2. Единые правила
- Корреляционный id: `X-Request-Id` (генерировать, если нет)
- Единый формат ошибок (JSON):
  - `success: false`
  - `message`
  - `code` (опционально)
  - `details` (опционально)

### 6.3. БД и миграции
- Решение: 1 БД, 3 схемы: `users`, `auth`, `events`.
- Для каждого Java-сервиса Flyway настроить на свою схему:
  - `spring.flyway.schemas=users` (или `auth`, `events`)
  - `spring.jpa.properties.hibernate.default_schema=users`

## 7) Структура Java-проектов
Рекомендация: завести рядом новую папку, чтобы не ломать Go код:
- `services-java/users-service/`
- `services-java/auth-service/`
- `services-java/events-service/`

Каждый сервис — отдельный Spring Boot проект (Gradle или Maven).

## 8) Порядок переписывания (рекомендовано)
1) **users-service** (самый безопасный)
2) **events-service** (доменная логика + PostGIS)
3) **auth-service** (security сложнее, лучше когда база уже готова)

Если у тебя auth критичнее — можно поменять 1 и 3 местами, но это обычно медленнее.

## 9) План по сервисам

### A) `users-service` → Java
**Цель**: полностью заменить Go-версию, сохранив API.

Шаги:
1. Создать Spring Boot проект, базовую структуру: controller → service → repository.
2. Настроить Postgres подключение и Flyway:
   - `V1__init.sql` для таблиц users (и связанных сущностей, если есть)
3. Реализовать эндпоинты (MVP):
   - создание пользователя
   - получение профиля
   - обновление профиля
   - списки/поиск (если есть)
4. Валидация через `jakarta.validation` (аналог правил Go).
5. Тесты:
   - unit на сервисный слой
   - integration: Testcontainers Postgres + HTTP тесты
6. Обсервабилити:
   - `/actuator/health`, `/actuator/metrics`
7. Интеграция в инфраструктуру:
   - добавить сервис в compose, переменные окружения
   - переключить роутинг на Java

Definition of Done:
- 100% эндпоинтов users совпадают по контракту
- все миграции накатываются с нуля
- интеграционные тесты проходят
- есть быстрый rollback на Go


### B) `events-service` → Java
**Особенность**: PostGIS запросы, геопоиск, фильтры.

Шаги:
1. Модель данных событий (таблицы events, participants, categories и т.д.).
2. Flyway миграции в схеме `events`.
3. Реализация эндпоинтов:
   - CRUD событий
   - фильтрация
   - геопоиск/радиус (если есть)
4. Построение запросов:
   - начать с JPA + native queries для PostGIS
   - при усложнении: QueryDSL или Spring Data Specifications
5. Тесты:
   - Testcontainers Postgres (важно прогнать PostGIS функции)
   - тесты на фильтры и геозапросы

Definition of Done:
- производительность не хуже Go на типовых запросах
- корректные индексы (GiST/SP-GiST для гео)


### C) `auth-service` → Java
**Особенность**: безопасность, токены, rate limiting.

Шаги:
1. Определиться с моделью auth:
   - если сейчас используется Supabase JWT — в Java валидировать JWT (JWKS/secret) и выдачу оставить Supabase
   - если своя auth — реализовать login/refresh/rotate/revoke
2. Spring Security:
   - security filter chain
   - JWT validation + roles/authorities
3. Persisted state (если нужно): sessions/refresh tokens в схеме `auth`.
4. Rate limiting:
   - на API gateway (предпочтительно) или на сервисе
   - для сервиса: Bucket4j/Resilience4j (выбрать одно)
5. Тесты:
   - unit: token service
   - integration: auth flows + негативные кейсы

Definition of Done:
- токены совместимы с текущими клиентами
- корректные статусы/ошибки (`401/403`)
- покрыты сценарии: регистрация/логин/refresh/logout

## 10) Общие задачи для всех сервисов
- Конфигурация через env:
  - `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
  - `SERVER_PORT`
- Логи: JSON/структурированные поля (requestId, userId).
- Документация: Swagger UI на `/swagger-ui`.
- Версионирование API: префикс `/api` + при необходимости `/v1`.

## 11) Изменения в Docker Compose (черновик)
- Добавить 3 Java сервиса рядом с Go (на время миграции):
  - `users-service-java:8081`
  - `events-service-java:8082`
  - `auth-service-java:8083`
- Подключить их к `postgres`.
- Включить healthchecks на `/actuator/health`.

## 12) План переключения и отката
- Переключение по сервису:
  1) поднять Java + прогнать smoke tests
  2) включить прокси-роут на Java
  3) мониторить ошибки/латентность
- Откат:
  - вернуть роутинг на Go
  - Java сервис оставить поднятым для диагностики

## 13) Риски и как их снять
- Несовпадение DTO/ошибок → контракт-тесты по OpenAPI.
- PostGIS нюансы → интеграционные тесты на реальном Postgres/PostGIS.
- Auth ошибки → сначала сделать read-only/validate-only режим (валидация токенов), затем расширять.

## 14) Примерный таймлайн (реалистично)
- Week 1: инвентаризация + users-service Java MVP + тесты
- Week 2: users-service стабилизация + events-service MVP
- Week 3: events-service стабилизация + auth-service MVP
- Week 4: hardening (security, наблюдаемость, нагрузка, документация)

---

### Следующий шаг (с чего начать прямо сейчас)
1) Снять список эндпоинтов Go сервисов (users/auth/events).
2) Зафиксировать OpenAPI (хотя бы руками) и «эталонные» ответы.
3) Начать с `users-service` на Java.
