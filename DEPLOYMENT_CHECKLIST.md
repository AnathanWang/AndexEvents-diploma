# 🚀 Deployment Checklist

Используйте этот чеклист перед каждым деплоем в production.

## Pre-Deployment (Разработка)

### Код и тесты
- [ ] Все unit тесты проходят: `flutter test`
- [ ] Все integration тесты проходят
- [ ] Код прошел code review
- [ ] Нет TODO комментариев в критичных местах
- [ ] Все console.log/print удалены или заменены на proper logging

### Версионирование
- [ ] Версия обновлена в `pubspec.yaml` (1.2.3 → 1.2.4)
- [ ] Build number увеличен: `version: 1.2.4+5`
- [ ] Changelog обновлен: [docs/changelog.md](docs/changelog.md)
- [ ] Git tag создан: `git tag v1.2.4`

### Configuration
- [ ] Backend API endpoint указывает на production
- [ ] Firebase project = production (не dev!)
- [ ] Yandex API keys = production keys
- [ ] Debug режим отключен (`kDebugMode` checks работают)
- [ ] Логирование снижено до WARNING/ERROR level

## Security Audit

### API Keys
- [ ] Yandex MapKit key — отдельный для production
- [ ] Yandex Geocoding key — отдельный для production
- [ ] Ключи **НЕ** захардкожены в коде
- [ ] Проверка: `git log -p | grep -i "31d10366\|e1866e10"` → нет результатов
- [ ] `.gitignore` включает:
  - [ ] `secrets/`
  - [ ] `.vscode/launch.json`
  - [ ] `android/key.properties`
  - [ ] `ios/Secrets.xcconfig`

### GitHub Secrets (CI/CD)
- [ ] `YANDEX_MAPKIT_API_KEY` настроен
- [ ] `YANDEX_GEOCODING_API_KEY` настроен
- [ ] `ANDROID_KEYSTORE_BASE64` настроен
- [ ] `ANDROID_KEYSTORE_PASSWORD` настроен
- [ ] `ANDROID_KEY_PASSWORD` настроен
- [ ] `ANDROID_KEY_ALIAS` = "upload"

### API Restrictions (Yandex Dashboard)
- [ ] MapKit key:
  - [ ] Bundle ID: `com.andexevents.app`
  - [ ] Platform restrictions: iOS + Android only
  - [ ] Rate limit: appropriate для production
- [ ] Geocoding key:
  - [ ] Referer restrictions: `andexevents.com`
  - [ ] Rate limit: 10000 req/day (или подходящий)

## Android Build

### Signing Configuration
- [ ] Keystore файл создан: `upload-keystore.jks`
- [ ] Keystore НЕ в Git репозитории
- [ ] `android/key.properties` создан и заполнен
- [ ] `android/key.properties` в `.gitignore`
- [ ] Проверка: `keytool -list -keystore upload-keystore.jks` работает

### Build & Test
- [ ] Local test build: `./scripts/build-production.sh android`
- [ ] APK создан: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] APK размер разумный (< 50MB)
- [ ] APK установлен и work на реальном Android устройстве
- [ ] Тест: создание события → геокодинг работает
- [ ] Тест: вход/регистрация → Firebase auth работает
- [ ] Тест: загрузка фото → upload service работает

### Google Play Console
- [ ] App Bundle собран: `./scripts/build-production.sh appbundle`
- [ ] AAB размер < APK размера
- [ ] Store listing заполнен:
  - [ ] Название: "AndexEvents"
  - [ ] Short description (80 chars)
  - [ ] Full description (4000 chars)
  - [ ] Скриншоты: минимум 2 для phone, 1 для tablet
  - [ ] Feature graphic: 1024x500px
  - [ ] App icon: 512x512px
- [ ] Content rating получен
- [ ] Privacy Policy URL указан и доступен
- [ ] Target API level ≥ 33 (Android 13)

## iOS Build

### Certificates & Provisioning
- [ ] Apple Developer account активен
- [ ] Distribution certificate создан
- [ ] App ID зарегистрирован: `com.andexevents.app`
- [ ] Provisioning profile создан (App Store Distribution)
- [ ] Xcode signing настроен: Team выбран

### Build & Test
- [ ] `ios/Secrets.xcconfig` создан с production ключами
- [ ] Xcode build успешен: `./scripts/build-production.sh ios`
- [ ] Simulator test: app запускается
- [ ] Real device test: установка и работа
- [ ] Push notifications работают (если используются)
- [ ] Геокодинг и карты работают

### App Store Connect
- [ ] App created в App Store Connect
- [ ] Bundle ID совпадает: `com.andexevents.app`
- [ ] Build uploaded через Xcode/Transporter
- [ ] App metadata заполнена:
  - [ ] Name: "AndexEvents"
  - [ ] Subtitle (30 chars)
  - [ ] Description
  - [ ] Keywords
  - [ ] Screenshots (всех требуемых размеров)
  - [ ] App preview video (optional)
- [ ] Privacy Policy URL
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Age rating: appropriate
- [ ] Export compliance: completed

## Backend & Infrastructure

### Services Health
- [ ] Auth service health check: `curl https://api.andexevents.com/auth/health`
- [ ] Events service health check: `curl https://api.andexevents.com/events/health`
- [ ] Upload service health check: `curl https://api.andexevents.com/upload/health`
- [ ] Database migrations applied
- [ ] Database backup создан перед деплоем

### Docker & Deployment
- [ ] Docker images собраны: `docker-compose build`
- [ ] Docker images pushed to registry
- [ ] Containers запущены: `docker-compose up -d`
- [ ] Logs чистые от errors: `docker-compose logs --tail=100`
- [ ] Мониторинг настроен (Prometheus/Grafana)

### Environment Variables (Production)
- [ ] `DATABASE_URL` указывает на production DB
- [ ] `JWT_SECRET` — strong & unique
- [ ] `CORS_ORIGINS` включает production домен
- [ ] `MINIO_ENDPOINT` = production MinIO/S3
- [ ] Storage buckets созданы и доступны

## Monitoring & Analytics

### Firebase
- [ ] Firebase Crashlytics включен
- [ ] Firebase Analytics включен
- [ ] Performance monitoring включен
- [ ] Test crash report: проверьте что отправляется

### Yandex APIs
- [ ] Dashboard: https://developer.tech.yandex.ru/
- [ ] Quota monitoring настроен
- [ ] Alert notifications включены (при 80% quota)
- [ ] Billing information актуальна

### Application Monitoring
- [ ] Sentry/Error tracking настроен (optional)
- [ ] Health check endpoints работают
- [ ] Database connection pool размер оптимизирован
- [ ] Redis/cache работает (если используется)

## Post-Deployment Verification

### Smoke Tests (First 30 minutes)
- [ ] App downloads from store
- [ ] Запуск на fresh install
- [ ] Регистрация нового пользователя
- [ ] Логин существующего пользователя
- [ ] Создание события (с геокодингом)
- [ ] Загрузка фото события
- [ ] Просмотр списка событий
- [ ] Push notification получено (если есть)

### Monitoring (First 24 hours)
- [ ] Crashlytics: crash-free rate > 99%
- [ ] API error rate < 1%
- [ ] Yandex API quota usage нормальный
- [ ] Database connection pool не переполнен
- [ ] Response times < 500ms для 95% requests

### User Feedback
- [ ] Store reviews мониторятся
- [ ] Support email проверяется
- [ ] Социальные сети проверены на упоминания
- [ ] Критические баги зарегистрированы как issues

## Rollback Plan

### Если что-то пошло не так:

1. **Немедленно:**
   ```bash
   # Откатитесь на предыдущий стабильный tag
   git checkout v1.2.3
   ./scripts/build-production.sh android
   ```

2. **Google Play:**
   - Release management → Production track
   - "Halt rollout" или "Rollback to previous version"

3. **App Store:**
   - App Store Connect → выберите версию
   - "Remove from Sale" (временно)
   - Или submit hotfix с expedited review

4. **Backend:**
   ```bash
   # Откатите Docker images
   docker-compose down
   git checkout v1.2.3
   docker-compose up -d
   ```

## Final Sign-off

- [ ] **Product Owner** approved release
- [ ] **Tech Lead** reviewed checklist
- [ ] **QA** signed off on tests
- [ ] **DevOps** confirmed infrastructure ready
- [ ] **Support Team** notified of release

### Release Info

- **Version:** __________ (e.g., 1.2.4)
- **Build Number:** __________ (e.g., 5)
- **Date:** __________ 
- **Release Manager:** __________
- **Git Tag:** __________ (e.g., v1.2.4)
- **Rollback Tag:** __________ (e.g., v1.2.3)

---

**После успешного деплоя:**
1. ✅ Отметьте версию как stable в Git
2. 📝 Обновите статус в [ROADMAP.md](ROADMAP.md) (или актуальный документ проекта)
3. 🎉 Объявите релиз команде
4. 📊 Установите monitoring alerts для новой версии

**Документы:**
- [Production Deployment Guide](docs/production-deployment.md)
- Секреты локально: каталог `secrets/` (см. [docs/setup.md](docs/setup.md) → Secrets)
- [Architecture](docs/architecture.md)
