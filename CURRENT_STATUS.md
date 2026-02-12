# Текущий статус проекта Andex Events

**Дата:** 12 Февраля 2026
**Состояние:** Активная разработка / Рефакторинг

## 1. Текущая архитектура

### Backend (Микросервисы)
*   **Архитектура:** Hybrid Microservices.
*   **Node.js Backend:** Перемещен в `legacy/backend`. Больше не является основным.
*   **Active Services (Docker):**
    *   `users-service` (Java/Spring)
    *   `events-service` (Java/Spring)
    *   `auth-service` (Java/Spring)
    *   `match-service` (Go)
    *   `upload-service` (Go)
*   **Инфраструктура:**
    *   **Gateway:** Traefik (единая точка входа `/api`).
    *   **DB:** PostgreSQL.
    *   **Storage:** MinIO (S3-compatible) для загрузки файлов.
    *   **Auth:** Firebase Auth + Custom JWT logic depending on service.

### Frontend (Flutter)
*   **Состояние:** Стабильное, но требует архитектурных улучшений.
*   **Функционал:**
    *   ✅ Авторизация / Регистрация.
    *   ✅ Профиль пользователя.
    *   ✅ Лента событий.
    *   ✅ Матчинг (Lite версия).
    *   ❌ Друзья (Функционал полностью удален из приложения).
*   **Исправления:**
    *   Устранены критические ошибки с `BuildContext` и асинхронностью (`mounted` checks).
    *   Исправлены ошибки потока управления (`return` в `finally`).

---

## 2. Что требует улучшения (Roadmap)

### 🔴 Приоритет: Высокий (Технический долг Flutter)
1.  **Dependency Injection (DI):**
    *   *Проблема:* Сервисы создаются прямо в виджетах (`AuthBloc(authService: AuthService())`). Тестировать невозможно.
    *   *Решение:* Внедрить `get_it` + `injectable` для управления зависимостями.
2.  **Навигация:**
    *   *Проблема:* Сейчас используется нативная навигация `Navigator.push`, местами хардкод переходов.
    *   *Решение:* Перейти на `go_router` или `auto_route` для поддержки Deep Links и Web.
3.  **Deprecated API:**
    *   *Задча:* Заменить все вызовы `color.withOpacity(...)` на новый синтаксис `color.withValues(alpha: ...)` (Flutter 3.22+).
4.  **Сетевой слой:**
    *   *Задача:* В проекте смешаны `http` и `dio`. Нужно привести всё к единому клиенту (`Dio`) с интерцепторами для логирования и обработки токенов.

### 🟡 Приоритет: Средний (Бэкенд и Инфраструктура)
1.  **API Gateway Routing:**
    *   Убедиться, что все маршруты из старого Node.js бэкенда корректно покрыты новыми микросервисами в Traefik.
2.  **Тесты:**
    *   Полное отсутствие тестов на Go/Java сервисах. Нужно написать хотя бы Integration тесты для критических путей (Регистрация, Создание события).

### 🟢 Приоритет: Низкий (UI/UX)
1.  **Логирование:**
    *   Заменить `print()` на нормальный `LoggerService` (пакет `logger` или `logging`), чтобы в релизе логи не светились.

---

## 3. Как запускать проект сейчас

**Backend:**
```bash
docker-compose -f deployments/docker/docker-compose.hybrid.yml up -d
```

**Flutter:**
*Для iOS Simulator:*
```bash
flutter run --dart-define=API_BASE_URL=http://localhost/api
```
*Для Android Emulator:*
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api
```
