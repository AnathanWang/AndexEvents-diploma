# 10. Клиент Flutter

## 10.1 Назначение слоёв

| Слой | Каталог | Ответственность |
|------|---------|-----------------|
| Presentation | `lib/presentation/` | UI (Material), экраны, BLoC, навигация |
| Data | `lib/data/` | Модели, сервисы доступа к REST API |
| Core | `lib/core/` | Конфигурация приложения, логирование, работа с Firebase token |
| App | `lib/app/` (если есть) | Сборка приложения, темы, провайдеры |

Админские экраны и виджеты находятся в `lib/presentation/admin/` (при наличии в ветке).

## 10.2 Конфигурация API (`AppConfig`)

Файл: **`lib/core/config/app_config.dart`**.

**Базовый URL (`baseUrl`):**

1. Если задан `--dart-define=API_BASE_URL=...` — используется он.
2. Иначе в **release**: `https://api.andexevents.com/api`.
3. Иначе в **debug**:
   - Web: `{scheme}://{host}/api`
   - Android эмулятор: `http://10.0.2.2/api` (хост-машина)
   - iOS/macOS: `http://localhost/api`

Для **физического устройства** необходимо указать IP компьютера или полный `API_BASE_URL`, иначе `localhost` указывает на телефон.

**Прочие константы** (фрагмент):

- `connectionTimeout` / `receiveTimeout`: по 30 секунд
- `eventsPerPage`: 20
- `matchesPerPage`: 10
- лимиты расстояний для матчинга в метрах (`defaultMaxDistance`, `minDistance`, `maxDistance`)

## 10.3 Ключи Yandex

В коде **не хранятся** секреты карт. Передача через `--dart-define`:

- `YANDEX_MAPKIT_API_KEY`
- `YANDEX_API_KEY` (геокодинг)
- `YANDEX_MAPS_API_KEY`

См. также `docs/setup.md` и скрипты в `scripts/`.

## 10.4 Сетевой стек

Основной HTTP-клиент — пакет **`http`**. Отдельные сервисы (например геокодинг) могут использовать другие клиенты — проверять импорты в `lib/data/services/`.

Запросы к защищённым эндпойнтам должны включать:

```http
Authorization: Bearer <firebase-id-token>
```

Механизм получения токена — через Firebase SDK и обёртки в `lib/core/auth/` (названия классов уточнять в репозитории).

## 10.5 Управление состоянием

Используется паттерн **BLoC** и неизменяемые состояния (часто с `equatable`). Логирование вместо `print` — через **`LoggerService`** в core.

## 10.6 Сборка и запуск

```bash
flutter pub get
flutter run --dart-define=YANDEX_MAPKIT_API_KEY=<key>
```

iOS может потребовать `pod install` в каталоге `ios/`.

Тесты:

```bash
flutter test
```

Production-сборки и подпись — **`DEPLOYMENT_CHECKLIST.md`**.
