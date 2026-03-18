# Andex Events 🎉

Мобильное приложение для поиска событий и знакомств с единомышленниками.

## 🚀 Функционал

### ✅ Реализовано

- **Аутентификация**
  - Онбординг с 3 экранами
  - Вход и регистрация
  - Вход через социальные сети (Google, Apple)
  - Режим гостя

- **События**
  - Карта событий с Yandex MapKit
  - Афиша событий
  - Детальный экран события
  - Создание события
  - Фильтрация по категориям

- **Матчи**
  - Tinder-style свайп интерфейс
  - Процент совпадения
  - Общие интересы

- **Профиль**
  - Просмотр своего профиля
  - Редактирование профиля
  - Выбор интересов (16 категорий)
  - Настройки приватности
  - Просмотр профилей других пользователей

## 🛠 Технологии

- **Flutter** 3.9.2+
- **Dart** 3.9.2+
- **Yandex MapKit** 4.1.0
- **Material Design 3**

## 🏗 Установка

### 1. Клонируйте репозиторий:
```bash
git clone https://github.com/YOUR_USERNAME/andexevents.git
cd andexevents
```

### 2. **ВАЖНО: Настройте Firebase конфигурацию**

Проект использует Firebase для аутентификации. Конфигурационные файлы **не включены** в репозиторий.

**Прочитайте инструкции**: [FIREBASE_SETUP.md](FIREBASE_SETUP.md)

Краткая версия:
```bash
# Скопируйте шаблон
cp lib/firebase_options.dart.example lib/firebase_options.dart

# Отредактируйте lib/firebase_options.dart и замените:
# - YOUR_ANDROID_API_KEY на ваш Android API Key
# - YOUR_IOS_API_KEY на ваш iOS API Key
```

Также загрузите из Firebase Console:
- `android/app/google-services.json` (Android)
- `ios/Runner/GoogleService-Info.plist` (iOS)

### 3. Установите зависимости:
```bash
flutter pub get
```

3. Для iOS выполните pod install:
```bash
cd ios
pod install
cd ..
```

4. Запустите приложение:
```bash
flutter run
```

## 🗺 Настройка Yandex MapKit и локальные секреты

1. Получите API ключи на https://developer.tech.yandex.ru/:
   - `MapKit` — для нативного SDK (Android/iOS).
   - `Geocoding` — для HTTP-запросов к геокодеру (бэкенд или клиентские запросы).
   Для продакшна рекомендуется использовать отдельные, ограниченные ключи.

2. Локальное хранение (рекомендованный поток для разработки)
   - В репозитории есть помощник `scripts/store_yandex_key.sh`, который создаёт нужные локальные (git-ignored) файлы и сохраняет туда ключи.
   - Запуск (MapKit + опционально Geocoding):
     ```
     sh ./scripts/store_yandex_key.sh <YANDEX_MAPKIT_KEY> [YANDEX_GEOCODE_KEY]
     ```
     Пример:
     ```
     sh ./scripts/store_yandex_key.sh e1866e10-6591-46c9-97b9-fbe8ad56a2f6 31d10366-2715-4f15-9fc7-a096fdda2be2
     ```
   - Что делает скрипт:
     - Записывает MapKit-ключ в `android/local.properties`, `ios/Secrets.xcconfig` и `secrets/yandex_mapkit_api_key.txt`.
     - Если указан Geocoding-ключ — записывает его в `backend/.env` и `secrets/yandex_geocode_api_key.txt`.
     - Устанавливает права 600 на созданные секретные файлы (ограничивает доступ).

3. Быстрый запуск для разработки (без правки кода вручную)
   - iOS (симулятор):
     - После выполнения скрипта просто запустите:
       ```
       flutter run
       ```
     - `ios/Flutter/Debug.xcconfig` включает `Secrets.xcconfig`, поэтому `Info.plist` автоматически увидит `$(YANDEX_MAPKIT_API_KEY)`.
   - Android:
     - Gradle использует `android/local.properties`. При необходимости можно экспортировать переменную:
       ```
       export ORG_GRADLE_PROJECT_YANDEX_MAPKIT_API_KEY=$(cat secrets/yandex_mapkit_api_key.txt)
       flutter run
       ```
   - Бэкенд (если используется Geocoding ключ):
     ```
     cd backend
     npm run dev
     ```
     Убедитесь, что `backend/.env` содержит `YANDEX_MAPS_API_KEY=...` (скрипт добавляет его при передаче второго аргумента).

4. Как использовать ключи в Flutter-коде
   - Для быстрого теста можно передать ключи через `--dart-define`:
     ```
     flutter run --dart-define=YANDEX_MAPKIT_API_KEY=$(cat secrets/yandex_mapkit_api_key.txt)
     flutter run --dart-define=YANDEX_API_KEY=$(cat secrets/yandex_geocode_api_key.txt)
     ```
   - В проекте `lib/config/map_config.dart` использует `String.fromEnvironment(...)`, поэтому `--dart-define` будет прочитан на уровне Dart.

5. Безопасность — обязательно
   - Не коммитьте в репозиторий: `secrets/`, `backend/.env`, `android/local.properties`, `ios/Secrets.xcconfig`.
   - Для продакшн храните ключи в CI/Secrets Manager и избегайте их вывода в логах.
   - Если старый ключ был публично доступен — отозовите/ротуйте его в панели Yandex (вы уже это сделали — правильно).

6. Если нужно автоматизировать ещё больше
   - Можно добавить `scripts/start-dev.sh`, который экспортирует переменные и запускает `flutter run` и/или бэкенд. Скажите — подготовлю.

## � Production Deployment

### Локальная сборка для Production

Используйте скрипт для автоматизированной production сборки:

```bash
# Android APK
./scripts/build-production.sh android

# Android App Bundle (для Google Play)
./scripts/build-production.sh appbundle

# iOS
./scripts/build-production.sh ios

# Web
./scripts/build-production.sh web
```

**Требования:**
- API ключи должны быть в `secrets/yandex_mapkit_api_key.txt` и `secrets/yandex_geocode_api_key.txt`
- Для signed Android builds: настройте `android/key.properties` и keystore
- Для iOS: подписание и архивация выполняются в Xcode

### CI/CD на GitHub Actions

Проект включает готовые workflows для автоматической сборки:

1. **Настройка GitHub Secrets** (Settings → Secrets and variables → Actions):
   ```
   YANDEX_MAPKIT_API_KEY        # Ваш Yandex MapKit API ключ
   YANDEX_GEOCODING_API_KEY     # Ваш Yandex Geocoding API ключ
   ANDROID_KEYSTORE_BASE64      # Base64-encoded Android keystore
   ANDROID_KEYSTORE_PASSWORD    # Пароль от keystore
   ANDROID_KEY_PASSWORD         # Пароль от ключа
   ANDROID_KEY_ALIAS            # Алиас ключа
   ```

2. **Android Build** (`.github/workflows/build-android.yml`):
   - Автоматически собирает APK при push в `main` или `develop`
   - Для release builds требуется настройка Android signing
   - Артефакты сохраняются на 30 дней

3. **iOS Build** (`.github/workflows/build-ios.yml`):
   - Автоматически собирает iOS app при push в `main`
   - Требует macOS runner (платный на GitHub)
   - Для подписи apps нужна дополнительная настройка certificates

### Создание Android Keystore

Для signed release builds:

```bash
# Создать keystore
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Конвертировать в Base64 для GitHub Secrets
base64 upload-keystore.jks > keystore.base64.txt

# Создать key.properties (НЕ коммитить!)
cat > android/key.properties << EOF
storePassword=ваш_пароль_keystore
keyPassword=ваш_пароль_ключа
keyAlias=upload
storeFile=upload-keystore.jks
EOF
```

### Безопасность в Production

**✅ Правильно:**
- Хранить ключи в GitHub Secrets / CI environment variables
- Использовать отдельные ключи для dev/staging/production
- Ограничить API ключи по домену/bundle ID
- Регулярно ротировать ключи

**❌ Неправильно:**
- Хардкодить ключи в коде
- Коммитить `.vscode/launch.json` с реальными ключами
- Использовать production ключи в development
- Публиковать ключи в логах CI/CD

### Мониторинг Production

После деплоя следите за:
- Квотами Yandex API (dashboard.yandex.ru)
- Ошибками в Firebase Crashlytics
- Производительностью через Firebase Performance
- Отзывами пользователей в Google Play / App Store

## �📦 Структура проекта

```
lib/
├── app/                    # Конфигурация приложения
├── config/                 # Конфигурационные файлы
├── presentation/
│   ├── auth/              # Аутентификация
│   ├── events/            # События
│   ├── home/              # Главный экран
│   ├── models/            # Модели данных
│   ├── onboarding/        # Онбординг
│   ├── profile/           # Профиль
│   └── widgets/           # Переиспользуемые виджеты
└── main.dart
```

## 🎨 Дизайн

- Цветовая схема: Фиолетовый (#5E60CE)
- UI/UX: Современный, минималистичный
- Скругления: 16-24px
- Тени и градиенты для глубины

## 📝 TODO

- [ ] Интеграция с бэкендом
- [ ] Чаты и сообщения
- [ ] Уведомления
- [ ] Отзывы о событиях
- [ ] Поиск и расширенные фильтры
- [ ] Интеграция платежей
- [ ] Темная тема

## 📄 Лицензия

MIT License
