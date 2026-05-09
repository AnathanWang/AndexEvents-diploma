# Andex Events

Монорепозиторий проекта **Andex Events**: Flutter-приложение + микросервисный backend (Java/Spring + Go) + инфраструктура для локального запуска и production.

## 📦 Что внутри

- **Mobile (Flutter)**: `lib/`, `android/`, `ios/`
- **Backend**
  - **Java services (Spring Boot)**: `services-java/` (например: `auth-service`, `users-service`, `events-service`)
  - **Go services**: `services/` (например: `match-service`, `upload-service`)
- **Infrastructure (Docker Compose)**: `deployments/docker/` (PostgreSQL, Redis, MinIO, Traefik и сервисы)

## ✅ Основные фичи (MVP)

- **Auth**: Firebase Authentication (email/password и др.)
- **Events**: лента + карта (Yandex MapKit), создание/просмотр событий
- **Matching**: Tinder-style свайпы, взаимные мэтчи
- **Profile & onboarding**: профиль, интересы, локация, настройки приватности

## 🧰 Технологии

- **Mobile**: Flutter, Dart, Yandex MapKit, Firebase (Auth/FCM)
- **Backend**: Java 21 (Spring Boot), Go 1.23+, PostgreSQL (+ PostGIS), Redis, MinIO (S3)
- **Ops**: Docker / Docker Compose, GitHub Actions

## 🚀 Быстрый старт (локальная разработка)

Полная и актуальная инструкция лежит в `docs/setup.md`.

1) Поднять инфраструктуру (PostgreSQL/Redis/MinIO):

```bash
cd deployments/docker
docker compose up -d postgres redis minio
```

2) Запустить backend сервисы (вариант через Docker):

```bash
cd deployments/docker
docker compose up -d auth-service users-service events-service match-service upload-service
```

3) Запустить Flutter приложение:

```bash
flutter pub get
flutter run --dart-define=YANDEX_MAPKIT_API_KEY=<your-key>
```

## 🔐 Firebase / ключи / секреты

- Инструкция по Firebase: `FIREBASE_SETUP.md`
- Секреты (например, `secrets/`) **не коммитятся** и хранятся локально (см. `docs/setup.md` → раздел Secrets).

## 📚 Документация

- **Техническое описание (основной документ):** `docs/technical/README.md`
- Индекс: `docs/README.md`
- Локальный запуск: `docs/setup.md`
- Roadmap: `ROADMAP.md`
- Production: `docs/production-deployment.md` и `DEPLOYMENT_CHECKLIST.md`
