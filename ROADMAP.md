# 🗺️ Roadmap AndexEvents — Что осталось реализовать

**Дата анализа:** 11 марта 2026  
**Обновлено:** 12 марта 2026 (добавлен TDD)  
**Текущая версия:** MVP (Alpha)  
**Статус проекта:** Активная разработка + TDD

**📊 Прогресс:** 2/49 задач выполнено (4.08%) 
- 🔴 Критические: 2/10 ✅
- 🟡 Высокие: 0/12
- 🟠 Средние: 0/18
- 🟢 Низкие: 0/9

---

## ✅ **Что уже работает**

- ✅ Firebase Authentication (Email + Password)
- ✅ Регистрация и вход пользователей
- ✅ Онбординг (настройка профиля, интересы, локация)
- ✅ Backend микросервисы (Java/Spring + Go/Gin)
- ✅ База данных (PostgreSQL + PostGIS)
- ✅ Создание и просмотр событий
- ✅ Геокодинг (Yandex Geocoding API)
- ✅ Загрузка фотографий (MinIO/S3)
- ✅ Swipe матчинг пользователей
- ✅ Админ-панель (модерация событий, управление пользователями, отчеты)
- ✅ Production deployment инфраструктура (CI/CD, GitHub Actions)

---

## 🎯 **Методология разработки**

### Test-Driven Development (TDD)

**Статус:** Активно применяется с 12 марта 2026

Все новые функции разрабатываются с использованием **TDD подхода**:

#### Цикл разработки (Red-Green-Refactor):

1. **🔴 RED — Написать тест**
   - Создать failing test для новой функции
   - Определить ожидаемое поведение
   - Убедиться, что тест падает (нет реализации)

2. **🟢 GREEN — Минимальный код**
   - Написать минимум кода для прохождения теста
   - Фокус на функциональности, не на красоте
   - Тест должен пройти

3. **♻️ REFACTOR — Улучшить код**
   - Рефакторинг без изменения поведения
   - Улучшить структуру и читаемость
   - Все тесты должны оставаться зелеными

#### Порядок реализации задач:

✅ **Строго по приоритету из ROADMAP:**
1. Сначала все 🔴 **Критические** задачи
2. Затем 🟡 **Высокоприоритетные**
3. Далее 🟢 **Средние**
4. В конце 🔵 **Технический долг**

#### Покрытие тестами:

- **Backend:** минимум 60% coverage (цель: 80%)
  - Unit tests для всех сервисов
  - Integration tests для критических флоу
  
- **Flutter:** минимум 70% coverage (цель: 85%)
  - Unit tests для BLoCs и Services
  - Widget tests для ключевых экранов
  - Integration tests для критических флоу

#### Инструменты:

**Backend (Java):**
```bash
# Запуск тестов с coverage
./mvnw clean test jacoco:report

# Просмотр отчета
open target/site/jacoco/index.html
```

**Flutter:**
```bash
# Запуск тестов с coverage
flutter test --coverage

# Генерация HTML отчета
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

#### Коммиты:

Каждый коммит должен включать:
- ✅ Тесты (red → green)
- ✅ Реализацию
- ✅ Документацию (если нужно)

Формат коммита:
```
feat(auth): add password reset with TDD

- Add failing test for password reset flow
- Implement resetPassword method in AuthService
- Add ForgotPasswordScreen UI
- All tests passing (coverage: 75%)

Refs: ROADMAP.md #1
```

---

## 📋 **Список нереализованных функций**

### 🔴 **КРИТИЧЕСКИ ВАЖНО (MVP)**

#### ✅ 1. **Валидация email адреса при регистрации** — ВЫПОЛНЕНО (12 марта 2026)
- **Файл:** `lib/presentation/auth/screens/register_screen.dart`
- **Статус:** ✅ Реализовано с TDD подходом
- **Commit:** `d979a7c` feat(auth): add email availability check with TDD
- **Тесты:** 15/15 passing (100% coverage)
  - AuthService: 7 unit tests ✅
  - RegisterScreen: 8 widget tests ✅
- **Реализация:**
  - ✅ Backend: `AuthService.checkEmailAvailability()` через Firebase
  - ✅ Debounce: 500ms delay для оптимизации API вызовов
  - ✅ UI: Real-time индикаторы (✅ Доступен, ❌ Занят, loading spinner)
  - ✅ Validation: Блокировка кнопки регистрации если email занят
  - ✅ Error handling: Network errors, invalid format
  - ✅ DI: Dependency injection для тестирования
- **Приоритет:** 🔴 Критический
- **Оценка:** 3-5 часов → **Фактически: 2.5 часа**

---

#### ✅ 2. **Восстановление пароля** — ВЫПОЛНЕНО (12 марта 2026)
- **Файл:** `lib/presentation/auth/screens/forgot_password_screen.dart`
- **Статус:** ✅ Реализовано с TDD подходом
- **Commit:** `5636ffc` feat(auth): add password reset with TDD
- **Тесты:** 20/20 passedинг (100% coverage)
  - AuthService: 6 unit tests ✅
  - AuthBloc: 5 bloc tests ✅
  - ForgotPasswordScreen: 9 widget tests ✅
- **Реализация:**
  - ✅ Backend: `AuthService.resetPassword()` с обработкой ошибок
  - ✅ BLoC: `AuthPasswordResetRequested` event handling
  - ✅ UI: ForgotPasswordScreen с валидацией email
  - ✅ Интеграция: Подключен к LoginScreen
  - ✅ UX: Success dialog, error snackbar, loading state
- **Приоритет:** Высокий
- **Оценка:** 2-4 часа → **Фактически: 2 часа**

---

#### 3. **Deep Links и Universal Links**
- **Статус:** Не реализовано (нужно для шаринга и уведомлений)
- **Сценарии:**
  - Открытие события по ссылке: `andexevents://event/{eventId}`
  - Открытие профиля: `andexevents://user/{userId}`
- **Компоненты:**
  - Android: Intent filters в `AndroidManifest.xml`
  - iOS: Associated Domains + Universal Links
  - Flutter: `app_links` или `uni_links` package
  - Навигация при старте приложения из deep link
- **Приоритет:** Высокий
- **Оценка:** 8-12 часов

#### 4. **Push уведомления** ❌
- **Статус:** Firebase подключен, но FCM не настроен
- **Компоненты:**
  - **Backend:**
    - Интеграция Firebase Admin SDK
    - Отправка уведомлений при:
      - Взаимном матче
      - Одобрении события
      - Напоминании о событии (за 1 час)
  - **Frontend:**
    - `firebase_messaging` package
    - Background/foreground message handlers
    - Local notifications (`flutter_local_notifications`)
    - Обработка tap на уведомление (deep link)
  - **Таблица:** `PushToken` (userId, token, platform)
- **Приоритет:** Критичный
- **Оценка:** 16-24 часа

---

### 🟡 **ВЫСОКИЙ ПРИОРИТЕТ (Пользовательский опыт)**

#### 4. **Шаринг событий**
- **Файл:** `lib/presentation/events/screens/event_detail_screen.dart:45`
- **TODO:**
  - Интеграция `share_plus` package
  - Генерация текста: "Название события — дата, место, ссылка"
  - Deep link для открытия события: `https://andexevents.com/event/{id}`
  - Шаринг изображения события (optional)
- **Зависимости:** Deep Links (#2)
- **Приоритет:** Средний
- **Оценка:** 3-4 часа

#### 5. **Отзывы и рейтинги событий** ❌
- **Статус:** Полностью отсутствует
- **Компоненты:**
  - **Backend:**
    - Таблица `Review`: id, eventId, userId, rating (1-5), comment, createdAt
    - API: POST `/api/events/{id}/reviews`, GET `/api/events/{id}/reviews`
    - Ограничение: только участники могут оставлять отзывы
  - **Frontend:**
    - Модель `ReviewModel`
    - Service: `ReviewService`
    - UI:
      - Отображение среднего рейтинга на карточке события
      - Список отзывов в `EventDetailScreen`
      - Форма оставить отзыв (после события)
      - Validation: событие уже прошло + пользователь был участником
- **Приоритет:** Средний
- **Оценка:** 16-20 часов

#### 6. **Расширенные фильтры и поиск**
- **Файл:** `lib/presentation/home/screens/events_feed_screen.dart`
- **Текущий статус:** Только категория
- **TODO:**
  - **Фильтры:**
    - Цена: слайдер (от-до) + "Бесплатные"
    - Дата: Сегодня / Завтра / Эта неделя / Выбрать даты
    - Расстояние: слайдер (1-50 км)
    - Онлайн/Оффлайн toggle
  - **Сортировка:**
    - По дате (ближайшие первые)
    - По популярности (больше участников)
    - По расстоянию
  - **Поиск:**
    - TextField с debounce
    - Поиск по title, description, location
    - Backend: Full-text search (PostgreSQL `tsvector`)
  - **UI:** Bottom sheet или отдельный экран фильтров
- **Приоритет:** Высокий
- **Оценка:** 12-16 часов

#### 7. **Настройки пользователя**
- **Файл:** `lib/presentation/profile/screens/edit_profile_screen.dart:691,703,717`
- **TODO:**
  - Создать `SettingsScreen`
  - **Приватность:**
    - Кто может видеть профиль
    - Показывать возраст
    - Показывать последнюю активность
  - **Язык:** Русский / English
  - **Тема:** Светлая / Темная / Системная
  - **Удалить аккаунт** (с подтверждением)
- **Приоритет:** Средний
- **Оценка:** 6-8 часов

---

### 🟢 **СРЕДНИЙ ПРИОРИТЕТ (Улучшения)**

#### 8. **Интеграция платежей** ❌
- **Статус:** Отсутствует (для платных событий)
- **Платежная система:** YooKassa (российский рынок) или Stripe (международный)
- **Компоненты:**
  - **Backend:**
    - Интеграция YooKassa SDK
    - Таблица `Payment`: id, userId, eventId, amount, status, paymentId
    - Webhook endpoint для подтверждения платежа
    - API: создание платежа, проверка статуса
  - **Frontend:**
    - Отображение цены на карточке события
    - Кнопка "Купить билет" → WebView с формой оплаты
    - Подтверждение успешной оплаты
    - Отображение "Билет куплен" в профиле пользователя
  - **Безопасность:**
    - Никакие данные карт не хранятся
    - Все через PCI DSS compliant провайдера
- **Приоритет:** Средний (зависит от бизнес-модели)
- **Оценка:** 24-32 часа

#### 9. **Открытие ссылок в профиле**
- **Файл:** `lib/presentation/home/screens/profile_screen.dart:559`
- **TODO:**
  - Интеграция `url_launcher` package
  - Клик на Instagram → открыть `instagram://` или web fallback
  - Клик на VK → `vk://` или web
  - Валидация корректности ссылок
- **Приоритет:** Низкий
- **Оценка:** 1 час

#### 10. **Admin — расширенные функции**
- **Текущий статус:** Базовая модерация работает
- **TODO:**
  - **Статистика:**
    - Графики активности пользователей (по дням/неделям)
    - Популярные категории событий
    - Конверсия: регистрации → активные пользователи
    - Package: `fl_chart` для графиков
  - **Экспорт отчетов:**
    - CSV: список пользователей, список событий
    - PDF: детальный отчет за период
  - **Bulk действия:**
    - Массовое одобрение событий (checkbox + "Одобрить все")
    - Массовая блокировка пользователей
  - **Audit log:**
    - Таблица `AuditLog`: adminId, action, targetId, timestamp
    - Логирование всех админских действий
    - UI просмотра лога
- **Приоритет:** Низкий
- **Оценка:** 16-24 часа

#### 11. **Темная тема**
- **Статус:** Частично реализована инфраструктура
- **TODO:**
  - Завершить темную тему для всех экранов
  - Проверить контрастность (accessibility)
  - Переключатель в настройках
  - Сохранение выбора в `LocalStorage`
  - Поддержка системной темы (`MediaQuery.platformBrightness`)
- **Приоритет:** Средний
- **Оценка:** 8-12 часов

#### 12. **Оффлайн режим**
- **Статус:** Отсутствует
- **Компоненты:**
  - **Локальное хранилище:**
    - `Hive` или `Drift` для кэширования
    - Кэшировать: список событий, профиль пользователя, матчи
  - **Синхронизация:**
    - При восстановлении интернета: sync pending actions
    - Conflict resolution (last-write-wins или custom logic)
  - **UI:**
    - Индикатор "Вы оффлайн" (banner вверху экрана)
    - Disabled actions: создание события, отправка сообщений
- **Приоритет:** Низкий
- **Оценка:** 20-28 часов

---

### 🔵 **НИЗКИЙ ПРИОРИТЕТ (Технический долг)**

#### 13. **Dependency Injection (DI)**
- **Текущий статус:** Ручное создание сервисов в `main.dart`
- **TODO:**
  - Интеграция `get_it` + `injectable`
  - Аннотации `@injectable`, `@singleton`
  - Code generation: `build_runner`
  - Refactor: убрать ручные зависимости
- **Преимущества:**
  - Легче тестировать (моки)
  - Чистый код
  - Lazy initialization
- **Приоритет:** Средний (для maintainability)
- **Оценка:** 6-8 часов

#### 14. **Навигация — миграция на go_router**
- **Текущий статус:** `Navigator.push` / `Navigator.pushNamed`
- **TODO:**
  - Интеграция `go_router`
  - Определение маршрутов декларативно
  - Deep links поддержка
  - Web URL routing
  - Query parameters
- **Преимущества:**
  - Более гибкая навигация
  - Web URL support
  - Type-safe маршруты
- **Приоритет:** Низкий
- **Оценка:** 8-12 часов

#### 15. **Deprecated API**
- **Проблема:** `Color.withOpacity()` deprecated в Flutter 3.27+
- **TODO:**
  - Найти все использования: `grep -r "withOpacity" lib/`
  - Заменить на: `color.withValues(alpha: opacity)`
  - Тестирование визуального регресса
- **Приоритет:** Низкий (пока warnings, не errors)
- **Оценка:** 2-3 часа

#### 16. **Сетевой слой — унификация на Dio**
- **Текущий статус:** `http` package
- **TODO:**
  - Миграция на `Dio`
  - **Интерцепторы:**
    - Auth interceptor (автоматическое добавление токена)
    - Logging interceptor (debug режим)
    - Refresh token interceptor (при 401)
  - **Retry logic:** Повтор при network errors
  - **Кэширование:** `dio_cache_interceptor`
  - **Better error handling:** Typed exceptions
- **Преимущества:**
  - Меньше boilerplate кода
  - Централизованная обработка ошибок
  - Лучшая производительность
- **Приоритет:** Средний
- **Оценка:** 12-16 часов

#### 17. **Логирование**
- **Текущий статус:** `print()` statements
- **TODO:**
  - Интеграция `logger` или `talker` package
  - Уровни: debug, info, warning, error
  - В production: только error логи
  - Опционально: отправка error логов на сервер (Sentry)
- **Приоритет:** Низкий
- **Оценка:** 4-6 часов

---

### 🧪 **ТЕСТИРОВАНИЕ**

#### 18. **Backend тесты** ❌
- **Статус:** Отсутствуют integration тесты
- **TODO:**
  - **Java сервисы:**
    - `@SpringBootTest` integration tests
    - TestContainers для PostgreSQL
    - Mock Firebase Auth
    - Критические флоу: регистрация, создание события, матчинг
  - **Go сервисы:**
    - Integration tests с `httptest`
    - Mock PostgreSQL / MinIO
  - **Coverage target:** минимум 60%
- **Приоритет:** Высокий (для production)
- **Оценка:** 40-60 часов

#### 19. **Flutter тесты** ⚠️
- **Текущий статус:** Минимальные unit тесты
- **TODO:**
  - **Unit тесты:**
    - Все BLoCs
    - Все Services
    - Models (toJson/fromJson)
  - **Widget тесты:**
    - Ключевые экраны (login, event detail, profile)
    - Формы (validation)
  - **Integration тесты:**
    - Golden tests (screenshot testing)
    - E2E критических флоу
  - **Coverage target:** 70%+
- **Приоритет:** Высокий
- **Оценка:** 60-80 часов

---

### 🔐 **БЕЗОПАСНОСТЬ**

#### 20. **2FA (Two-Factor Authentication)** ❌
- **Статус:** Запланировано
- **TODO:**
  - Backend: TOTP implementation (`otplib` или Java TOTP library)
  - Таблица `UserTwoFactor`: userId, secret, backupCodes, enabled
  - Frontend:
    - Setup 2FA screen (показать QR код)
    - Enter 2FA code при логине
    - Backup codes (сохранить в secure storage)
  - Package: `otp` для генерации кодов
- **Приоритет:** Средний (для безопасности)
- **Оценка:** 16-24 часа

#### 21. **Certificate Pinning** ❌
- **Статус:** Не реализовано
- **TODO:**
  - Интеграция `flutter_secure_networking` или custom Dio adapter
  - Пиннинг SSL сертификата production API
  - Защита от MITM атак
- **Приоритет:** Низкий (при наличии HTTPS)
- **Оценка:** 4-6 часов

#### 22. **Code Obfuscation** ❌
- **Статус:** Не настроено
- **TODO:**
  - Flutter: `--obfuscate --split-debug-info=/<directory>`
  - ProGuard для Android (нативный код)
  - Symbol stripping для iOS
  - Защита от reverse engineering
- **Приоритет:** Средний (для production)
- **Оценка:** 2-4 часа

---

### 📊 **АНАЛИТИКА И МОНИТОРИНГ**

#### 23. **Firebase Crashlytics — полная интеграция** ⚠️
- **Статус:** Firebase подключен, Crashlytics частично
- **TODO:**
  - Тестирование крашей (force crash button в debug)
  - Non-fatal errors reporting
  - Custom keys для контекста (userId, screen name)
  - ANR tracking (Android)
- **Приоритет:** Высокий
- **Оценка:** 4-6 часов

#### 24. **Firebase Analytics — полное логирование** ⚠️
- **Статус:** Частично
- **TODO:**
  - Логировать все критические действия:
    - `screen_view`: каждое открытие экрана
    - `sign_up`, `login`, `logout`
    - `event_created`, `event_joined`
    - `match_created`, `message_sent`
  - Custom parameters для событий
  - User properties (age, gender, premium status)
  - Funnels: анализ конверсии
- **Приоритет:** Средний
- **Оценка:** 8-12 часов

#### 25. **Backend мониторинг** ❌
- **Статус:** Отсутствует
- **TODO:**
  - **Prometheus + Grafana:**
    - Метрики: request rate, error rate, latency (P50, P95, P99)
    - JVM metrics (Java сервисы)
    - Go runtime metrics
    - PostgreSQL metrics (connections, query time)
    - MinIO metrics (upload/download speed)
  - **Health checks:**
    - Spring Actuator для Java (`/actuator/health`)
    - Custom health endpoints для Go
  - **Alerting:**
    - Telegram/Slack бот для критичных ошибок
    - Error rate > 5% → alert
    - API latency > 2s → alert
- **Приоритет:** Высокий (для production)
- **Оценка:** 24-32 часа

---

### 🎨 **UI/UX УЛУЧШЕНИЯ**

#### 26. **Skeleton loaders**
- **Текущий статус:** `CircularProgressIndicator`
- **TODO:**
  - Package: `shimmer` или `skeletons`
  - Skeleton для:
    - EventCard (пока загружаются события)
    - UserCard (пока загружаются пользователи)
    - Profile screen
  - Анимация "волна" для премиум-ощущения
- **Приоритет:** Низкий (UX улучшение)
- **Оценка:** 4-6 часов

#### 27. **Hero animations**
- **Текущий статус:** Базовые переходы
- **TODO:**
  - Hero animation для:
    - EventCard → EventDetailScreen (изображение)
    - UserCard → UserProfileScreen (аватар)
  - Shared element transitions
  - Smooth page transitions (custom PageRoute)
- **Приоритет:** Низкий
- **Оценка:** 6-8 часов

#### 28. **Accessibility (A11y)**
- **Статус:** Не реализовано
- **TODO:**
  - **Screen readers:**
    - Semantics виджеты для всех важных элементов
    - Тестирование TalkBack (Android) / VoiceOver (iOS)
  - **Контрастность:**
    - WCAG AA compliance (контрастность 4.5:1)
    - Проверка через `flutter analyze --accessibility`
  - **Размеры шрифтов:**
    - Поддержка system font scaling
  - **Keyboard navigation:** (для web/desktop версий)
- **Приоритет:** Средний
- **Оценка:** 12-16 часов

---

### 🌐 **ЛОКАЛИЗАЦИЯ**

#### 29. **Мультиязычность (i18n)**
- **Статус:** Хардкод на русском языке
- **TODO:**
  - Интеграция `flutter_localizations` + `intl`
  - ARB файлы: `app_ru.arb`, `app_en.arb`
  - Перевод всех строк:
    - UI labels
    - Error messages
    - Validation messages
  - Автоопределение языка по `Locale`
  - Переключатель языка в настройках
  - Backend API: поддержка `Accept-Language` header
- **Языки для старта:** Русский, English
- **Приоритет:** Средний (для международного запуска)
- **Оценка:** 16-24 часа

---

## 📈 **ПРИОРИТИЗАЦИЯ ПО ВРЕМЕНИ**

### 🚀 **Sprint 1: Следующая неделя (Beta MVP)**

**Цель:** Подготовка к закрытому бета-тестированию

| Задача | Приоритет | Оценка |
|--------|-----------|--------|
| Deep Links | 🔴 Критично | 8-12 ч |
| Push уведомления | 🔴 Критично | 16-24 ч |
| Восстановление пароля | 🟡 Высокий | 2-4 ч |

**Итого:** 26-40 часов (2 человека = 1-2 недели)

---

### 📱 **Sprint 2: Месяц 1 (Public Beta)**

**Цель:** Полноценный UX для публичной беты

| Задача | Приоритет | Оценка |
|--------|-----------|--------|
| Шаринг событий | 🟡 Высокий | 3-4 ч |
| Расширенные фильтры и поиск | 🟡 Высокий | 12-16 ч |
| Отзывы и рейтинги событий | 🟡 Высокий | 16-20 ч |
| Настройки пользователя | 🟡 Высокий | 6-8 ч |
| Backend тесты (критичные флоу) | 🧪 Тесты | 20-30 ч |
| Flutter тесты (unit + widget) | 🧪 Тесты | 30-40 ч |

**Итого:** 87-118 часов (2 человека = 2.5-3 недели)

---

### 🏢 **Sprint 3: Месяц 2-3 (Pre-Production)**

**Цель:** Подготовка к production запуску

| Задача | Приоритет | Оценка |
|--------|-----------|--------|
| Интеграция платежей (YooKassa) | 🟢 Средний | 24-32 ч |
| Firebase Crashlytics + Analytics | 📊 Мониторинг | 10-14 ч |
| Backend мониторинг (Prometheus) | 📊 Мониторинг | 24-32 ч |
| 2FA | 🔐 Безопасность | 16-24 ч |
| Code obfuscation | 🔐 Безопасность | 2-4 ч |
| Оффлайн режим | 🟢 Средний | 18-24 ч |
| Dependency Injection | 🔵 Долг | 6-8 ч |

**Итого:** 100-138 часов (2 человека = 3-4 недели)

---

### 🌍 **Sprint 4: Месяц 3-4 (Production + Scale)**

**Цель:** Production launch и масштабирование

| Задача | Приоритет | Оценка |
|--------|-----------|--------|
| Мультиязычность (Русский + English) | 🌐 i18n | 16-24 ч |
| Темная тема (полная) | 🟢 Средний | 8-12 ч |
| Admin расширенные функции | 🟢 Средний | 16-24 ч |
| Accessibility (A11y) | 🎨 UX | 12-16 ч |
| Skeleton loaders + Hero animations | 🎨 UX | 10-14 ч |
| Миграция на go_router | 🔵 Долг | 8-12 ч |
| Миграция на Dio | 🔵 Долг | 12-16 ч |

**Итого:** 82-118 часов (2 человека = 2.5-3 недели)

---

## 📊 **Общая статистика**

| Категория | Задач | Часов (мин-макс) |
|-----------|-------|------------------|
| 🔴 Критично | 3 | 26-40 |
| 🟡 Высокий | 4 | 31-44 |
| 🟢 Средний | 5 | 82-107 |
| 🔵 Долг | 5 | 28-40 |
| 🧪 Тесты | 2 | 100-140 |
| 🔐 Безопасность | 3 | 22-34 |
| 📊 Мониторинг | 3 | 34-46 |
| 🎨 UX | 3 | 22-30 |
| 🌐 i18n | 1 | 16-24 |

**Итого:** 29 задач, **361-505 часов** (2-3 месяца при 2 разработчиках)

---

## 🎯 **Рекомендации**

### 🔬 **TDD Workflow (применяется с 12 марта 2026):**

**Обязательный порядок:**
1. 📝 Написать failing test
2. ✅ Минимальная реализация (green)
3. ♻️ Рефакторинг
4. 🔄 Повторить для следующей фичи

**Никогда не коммитить код без тестов!**

---

### Для Beta тестирования (минимум):

**🔴 Критические задачи (в порядке приоритета):**
1. ✅ **Push уведомления** (критично для engagement) — начать отсюда
   - Начать с backend integration tests
   - Затем Flutter unit tests для FCM handler
   - Widget tests для notification UI
   
2. ✅ **Deep links** (для шаринга и уведомлений)
   - Unit tests для URL parsing
   - Integration tests для navigation
   
3. ✅ **Восстановление пароля**
   - Unit tests для AuthService.resetPassword
   - Widget tests для ForgotPasswordScreen

**Строго последовательно! Не начинать следующую задачу, пока не закончена предыдущая.**

---

### Для Public launch:

**После завершения ВСЕХ критических задач:**
- 🟡 Расширенные фильтры (с тестами для каждого фильтра)
- 🟡 Отзывы и рейтинги (TDD для ReviewService)
- 🟡 Платежи (если платные события)
- 📊 Мониторинг и Crashlytics
- 🧪 Достичь 70%+ coverage

---

### Для масштабирования:
- Полное тестирование (85%+ coverage для production)
- Backend мониторинг
- i18n для других рынков
- Accessibility для всех

---

### ⚠️ **Важные правила:**

1. **Один PR = одна задача из ROADMAP**
2. **Каждый PR должен включать тесты**
3. **Минимальный coverage для merge:**
   - Backend: 60%+
   - Flutter: 70%+
4. **Code review обязателен**
5. **CI/CD должен быть зеленым**

---

## 📝 **Примечания**

- **Оценки** даны для одного mid-level разработчика
- **Сложные задачи** (платежи, backend мониторинг) могут требовать больше времени при первой интеграции
- **Тестирование** — непрерывный процесс, оценки минимальные
- **Production deployment** инфраструктура уже готова (CI/CD, GitHub Actions) ✅

---

**Последнее обновление:** 12 марта 2026  
**Методология:** Test-Driven Development (TDD)  
**Ответственный:** Development Team  
**Статус:** В работе — MVP фаза + TDD
