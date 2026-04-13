# Andex Events 🎉

Мобильное приложение и бэкенд платформа для поиска событий и знакомств с единомышленниками.
Данный репозиторий представляет собой монорепо, объединяющий мобильный Flutter-клиент и микросервисный бэкенд.

## 🚀 Архитектура и Структура Проекта

- **Клиент (Mobile):** Flutter-приложение (`lib/`, `android/`, `ios/`)
- **Микросервисы (Backend):**
  - **Java Services:** Spring Boot сервисы (`services-java/`, например `users-service`, `events-service`).
  - **Go Services:** Go-сервисы (`services/`, например `match-service`).
- **Инфраструктура:** Docker Compose (`docker-compose.yml`) для локального развертывания базы данных (PostgreSQL), Redis и других зависимостей.

## ✅ Функционал Проекта

- **Аутентификация:** Firebase Auth (Email, Google, Apple), Режим гостя.
- **События:** Карта событий с Yandex MapKit, Афиша событий, Создание и детали событий.
- **Матчи & Знакомства:** Tinder-style свайп интерфейс, система взаимных симпатий и push-уведомлений (отправка через Go Backend).
- **Профиль:** Просмотр и редактирование профиля, настройки приватности и категории интересов.

## 🛠 Технологии

- **Мобильный клиент:** Flutter 3.19+, Dart 3.3+, Yandex MapKit 4.1.0, Firebase (Auth, Cloud Messaging).
- **Бэкенд:** Java 21 (Spring Boot), Go 1.21+, PostgreSQL.
- **Развертывание:** Docker, Docker Compose, GitHub Actions.

## 🏗 Установка и Запуск

### 1. Бэкенд и База Данных (Терминал 1)

Поднимите базу данных и микросервисы локально:
```bash
docker compose up -d --build
```
Это запустит PostgreSQL и соберет/запустит образы для Java и Go сервисов.

### 2. Мобильный Клиент (Терминал 2)

Установите зависимости Flutter:
```bash
flutter pub get
```

Для iOS установите pod-зависимости:
```bash
cd ios
pod install
cd ..
```

### 3. Firebase & Push Notifications

Проект использует Firebase (Auth, FCM). Конфигурация в репозиторий не включена.
**Инструкция:** См. файл [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
1. Положите конфигурации `google-services.json` в `android/app/` и `GoogleService-Info.plist` в `ios/Runner/`
2. Настройте файл `lib/firebase_options.dart` из шаблона `lib/firebase_options.dart.example`.

### 4. Yandex MapKit Ключи

Для работы карт нужен API-ключ Yandex MapKit. Вы можете сохранить его локально:
```bash
sh ./scripts/store_yandex_key.sh <YANDEX_MAPKIT_KEY> [YANDEX_GEOCODE_KEY]
```
Либо передавать напрямую при запуске:
```bash
flutter run --dart-define=YANDEX_MAPKIT_API_KEY=ваш_ключ
```

### 5. Запуск Приложения
```bash
flutter run
```

## 📦 Production Deployment

Проект включает скрипты сборки (`scripts/build-production.sh`) и базовые CI/CD пайплайны GitHub Actions для:
- Сборки подписанных Android APK / AAB.
- Сборки iOS-сборок (требует macOS Runner).
