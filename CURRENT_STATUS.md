# Текущий статус проекта Andex Events

**Дата:** 9 Марта 2026  
**Состояние:** Активная разработка - Auth & Navigation работают!

## ✅ Последние исправления (9 марта 2026)

### Firebase & Authentication
- ✅ Firebase инициализация работает (исправлен белый экран)
- ✅ Регистрация через Email + Password работает
- ✅ Вход через Email + Password работает  
- ✅ Backend создает пользователей в PostgreSQL
- ✅ Навигация после auth работает корректно

### Database Schema
- ✅ Все SQL запросы исправлены - используют qualified names (`users."User"`)
- ✅ Go сервисы (upload, match) работают с правильными схемами
- ✅ Java сервисы (users, events, auth) работают с правильными схемами

### Navigation Flow
- ✅ RegisterScreen → SetupProfileScreen (через `pushAndRemoveUntil`)
- ✅ LoginScreen → SetupProfileScreen или HomeShell (в зависимости от onboarding status)
- ✅ Кнопка "Назад" с подтверждением выхода (PopScope)

---

## 1. Текущая архитектура

### Backend (Микросервисы)
*   **Архитектура:** Hybrid Microservices - РАБОТАЕТ!
*   **Active Services (Docker):**
    *   ✅ `users-service` (Java/Spring) - порт 8081
    *   ✅ `events-service` (Java/Spring) - порт 8082
    *   ✅ `auth-service` (Java/Spring) - порт 8083
    *   ✅ `match-service` (Go) - порт 8005
    *   ✅ `upload-service` (Go) - порт 8006
*   **Инфраструктура:**
    *   **Gateway:** Traefik (порт 80) - `/api/*` routes
    *   **DB:** PostgreSQL 16 с schemas (users, events, auth, public)
    *   **Storage:** MinIO (S3-compatible) для файлов
    *   **Auth:** Firebase Auth + FirebaseJwtVerifier в каждом сервисе
    *   **Cache:** Redis

### Frontend (Flutter)
*   **Состояние:** Authentication & Navigation работают!
*   **Функционал:**
    *   ✅ Авторизация / Регистрация (Email + Password)
    *   🔄 Настройка профиля (SetupProfileScreen) - в процессе
    *   ❌ Лента событий - требует доработки
    *   ❌ Матчинг - требует доработки
    *   ❌ Загрузка фото - требует тестирования

---

## 2. Приоритеты на завтра (10 марта 2026)

### 🔴 ВЫСОКИЙ ПРИОРИТЕТ
1.  **Онбординг (SetupProfileScreen):**
    *   Завершить настройку профиля
    *   Сохранение данных (displayName, bio, age, gender, interests)
    *   Обновление `isOnboardingCompleted = true`
    *   Переход к HomeShell после завершения

2.  **Загрузка фотографий:**
    *   Интеграция upload-service с SetupProfileScreen
    *   Загрузка аватара пользователя
    *   Сохранение `photoUrl` в базу

### 🟡 СРЕДНИЙ ПРИОРИТЕТ  
3.  **Home Screen:**
    *   Реализация HomeShell с табами
    *   Отображение ближайших событий
    *   Навигация между разделами

4.  **События:**
    *   Создание событий через events-service
    *   Список событий
    *   Присоединение к событиям

### 🟢 НИЗКИЙ ПРИОРИТЕТ (Технический долг)
1.  **Dependency Injection (DI):**
    *   Внедрить `get_it` + `injectable`
2.  **Навигация:**
    *   Перейти на `go_router` для Deep Links
3.  **Deprecated API:**
    *   Заменить `color.withOpacity()` на `color.withValues(alpha: ...)`
4.  **Сетевой слой:**
    *   Унифицировать на `Dio` с интерцепторами

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
