# План улучшения проекта Andex Events

## 1. Flutter (Мобильное приложение)

### Приоритет: Критический (Стабильность)
- [ ] **Исправить `control_flow_in_finally`**: В `lib/presentation/profile/screens/user_profile_screen.dart`. Это скрывает ошибки и делает поведение непредсказуемым.
- [ ] **Исправить `use_build_context_synchronously`**: В `setup_profile_screen.dart` и `edit_profile_screen.dart`. Добавить проверки `if (!context.mounted) return;` перед использованием `context` после `await`.
- [ ] **Заменить deprecated методы**: `withOpacity` -> `withValues`, `geolocator` settings.

### Приоритет: Высокий (Архитектура и Масштабируемость)
- [ ] **Внедрить Dependency Injection (DI)**:
    - *Текущее состояние:* Сервисы создаются напрямую в виджетах (`AuthBloc(authService: AuthService())`), что делает невозможным мокирование и тестирование.
    - *Рекомендация:* Использовать `get_it` + `injectable` для регистрации зависимостей.
- [ ] **Clean Architecture (Domain Layer)**:
    - *Текущее состояние:* `Presentation` (Bloc) -> `Data` (Service). Нет четкого разделения бизнес-логики и работы с данными.
    - *Рекомендация:* Выделить слой `Domain` (Сущности, Интерфейсы репозиториев, UseCases). Это позволит менять реализацию данных (например, Supabase -> MinIO) без изменения UI.
- [ ] **Улучшить Навигацию**:
    - *Текущее состояние:* Ручное переключение виджетов в `_buildHome` (`if state is ... return HomeShell`).
    - *Рекомендация:* Внедрить `go_router` или `auto_route` для декларативной навигации, диплинков и лучшей обработки стека экранов.

### Приоритет: Средний (Качество кода)
- [ ] **Сервис логирования**:
    - Заменить 100+ вызовов `print()` на `LoggerService`. Использование `print` в продакшене засоряет логи и может влиять на производительность.
- [ ] **Статический анализ**: Исправить warnings (`curly_braces_in_flow_control_structures`, `unused_import`).
- [ ] **Конфигурация**: Рассмотреть пакет `envied` для безопасного хранения ключей вместо `String.fromEnvironment` (хотя текущий подход приемлем).

## 2. Backend (Node.js/TypeScript)

### Приоритет: Высокий
- [ ] **Унификация бэкенда**:
    - *Проблема:* В репозитории код на Node.js (`backend/`), Go (`services/`) и Java (`services-java/`).
    - *Рекомендация:* Официально закрепить `backend/` (Node.js) как основной, а остальные перенести в архив (`archive/` или `legacy/`), чтобы не путать новых разработчиков.
- [ ] **Тестирование**: Добавить Unit и Integration тесты (Jest/Supertest). Сейчас тестов нет (`"test": "echo \"Error: no test specified\""`).

### Приоритет: Средний
- [ ] **Валидация конфигурации**: Использовать `envalid` или `zod` для проверки переменных окружения при старте (DB_URL, JWT_SECRET), чтобы сервис падал сразу при ошибке конфига.

## 3. DevOps и Инфраструктура
- [ ] **CI/CD**: Настроить GitHub Actions для запуска `flutter analyze` и `flutter test` при пулл-реквестах.
- [ ] **Docker**: Убедиться, что Docker Compose поднимает `backend` и зависимые сервисы (MinIO, Postgres).

## Итог: Что сделать предпочтительнее (Quick Wins)
1.  **Flutter**: Исправить баг с `finally` и `BuildContext` (займет 15 минут, спасет от крэшей).
2.  **Flutter**: Настроить `get_it` (заложит фундамент для нормальной разработки).
3.  **Backend**: Удалить/Спрятать лишние папки (`services/`, `services-java/`), чтобы навести порядок в структуре.
