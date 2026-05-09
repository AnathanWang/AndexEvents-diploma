# 5. Backend на Java (Spring Boot)

Расположение: **`services-java/`**. Три независимых деплойных артефакта: `auth-service`, `users-service`, `events-service`.

## 5.1 Общие технические свойства

| Аспект | Реализация |
|--------|------------|
| JDK | 21 |
| Framework | Spring Boot 3.3.x |
| Доступ к данным | JDBC, типично `JdbcTemplate` / репозитории без единого ORM на весь монорепозиторий |
| Миграции | Flyway, каталог `src/main/resources/db/migration/` в каждом модуле |
| Проверка Firebase JWT | Классы вида `FirebaseJwtVerifier`, фильтры на HTTP-цепочке (см. пакет `...auth` в каждом сервисе) |
| Health | Spring Boot Actuator: например `GET /actuator/health` на порту сервиса |
| CORS | Отдельные конфигурационные классы Web (например `WebCorsConfig`) |

База данных одна на всё окружение — **`andexevents`**, изоляция доменов через **отдельные схемы** PostgreSQL.

## 5.2 auth-service

**Путь:** `services-java/auth-service/`  
**Порт по умолчанию:** 8083  
**Схема Flyway:** `auth` (в основном история миграций и служебные объекты).

**Назначение:** сервис без собственной бизнес-таблицы пользователя; проверяет Firebase ID token и сопоставляет внешний идентификатор с записью в **`users."User"`** (cross-schema чтение).

Ключевые компоненты (пакет `com.andexevents.auth`):

| Компонент | Роль |
|-----------|------|
| `AuthFilter` | Перехват запросов, извлечение Bearer token |
| `FirebaseJwtVerifier` | Проверка подписи JWT по JWKS Firebase |
| `UserLookupRepository` | Поиск внутреннего user id по данным из токена / таблицы пользователей |
| `AuthContext` | Контекст запроса: uid, email, internal userId |
| `AuthController` | REST `/api/auth/...` |
| `SupabaseJwtVerifier` | Исторический/альтернативный путь верификации (наличие в коде — для совместимости; основной путь для продукта — Firebase) |

`FLYWAY_ENABLED` для auth в типичном локальном сценарии может отличаться от users/events — см. `docs/setup.md`.

## 5.3 users-service

**Путь:** `services-java/users-service/`  
**Порт:** 8081  
**Схема БД:** `users`  
**Владелец таблицы:** `"User"` (+ миграции вроде отчётов, см. `V3__add_reports.sql` и др.).

**Назначение:** профиль пользователя, онбординг, обновление локации, операции, связанные с пользователем (включая отчёты в актуальной версии миграций).

Особенности:

- Использование **PostGIS** для пространственных запросов (например поиск «рядом»), см. репозитории и SQL в коде.
- Те же паттерны безопасности: фильтр + верификация JWT.

## 5.4 events-service

**Путь:** `services-java/events-service/`  
**Порт:** 8082  
**Схема БД:** `events`  
**Таблицы:** `"Event"`, `"Participant"` (и связанные ограничения/индексы из Flyway).

**Назначение:** CRUD событий, участие, модерация (`PENDING` / `APPROVED` / `REJECTED` — конкретные enum и поля см. в миграциях), геопоиск через PostGIS (`ST_DWithin`, подготовка точек в формате geography и т.д.).

## 5.5 Формат ответов Java-сервисов

Типичная обёртка описана в **`docs/api-reference.md`** (`success`, `data`, `message`). Конкретные DTO смотреть в контроллерах и классах `ApiResponse`.

## 5.6 Сборка и запуск (кратко)

Из корня Java-проекта:

```bash
cd services-java
./mvnw clean package -DskipTests
```

Запуск JAR каждого сервиса или через Docker — см. [`../setup.md`](../setup.md) и `deployments/docker/docker-compose.yml`.
