# 🚀 Production Deployment Guide

## Обзор

Этот документ описывает процесс деплоя AndexEvents в production среду с безопасным хранением API ключей.

## Архитектура безопасности

```
Development          →  Staging           →  Production
─────────────────────────────────────────────────────────
.vscode/launch.json  →  CI/CD Secrets    →  CI/CD Secrets
(локально)              (GitHub Actions)     (GitHub Actions)
                                              + App Stores
```

## Этап 1: Подготовка API ключей

### Yandex API Keys

1. Получите **отдельные** ключи для production на https://developer.tech.yandex.ru/
   - MapKit API key (для нативных карт)
   - Geocoding API key (для поиска адресов)

2. Настройте ограничения:
   ```
   MapKit Key:
   - Bundle ID: com.andexevents.app
   - Только iOS/Android platforms
   
   Geocoding Key:
   - Referer: andexevents.com
   - Rate limit: 10000 req/day
   ```

### Firebase Configuration

1. Скачайте production конфигурации:
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)

2. Разместите в правильные директории:
   ```
   android/app/google-services.json
   ios/Runner/GoogleService-Info.plist
   ```

## Этап 2: Локальная Production сборка

### Предварительные требования

```bash
# Установите API ключи локально
sh ./scripts/store_yandex_key.sh \
  YOUR_PROD_MAPKIT_KEY \
  YOUR_PROD_GEOCODING_KEY
```

### Android Release Build

#### Шаг 1: Создайте Keystore

```bash
# Генерация нового keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Ответьте на вопросы:
# - Пароль keystore: [придумайте сложный пароль]
# - Имя и фамилия: AndexEvents
# - Организация: YourCompany
# - Город/Страна: Moscow/RU
```

#### Шаг 2: Настройте signing config

```bash
# Создайте android/key.properties
cat > android/key.properties << EOF
storePassword=ваш_пароль_keystore
keyPassword=ваш_пароль_ключа
keyAlias=upload
storeFile=/путь/к/upload-keystore.jks
EOF

# ⚠️ НЕ КОММИТЬТЕ key.properties в Git!
```

#### Шаг 3: Соберите APK/AAB

```bash
# APK для прямой установки
./scripts/build-production.sh android

# App Bundle для Google Play
./scripts/build-production.sh appbundle
```

Результат:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### iOS Release Build

#### Шаг 1: Настройте Xcode

1. Откройте `ios/Runner.xcworkspace` в Xcode
2. Выберите Team в Signing & Capabilities
3. Убедитесь, что Bundle ID: `com.andexevents.app`

#### Шаг 2: Соберите через скрипт

```bash
./scripts/build-production.sh ios
```

#### Шаг 3: Архивируйте и отправьте в App Store

1. В Xcode: Product → Archive
2. Выберите архив → Distribute App
3. Следуйте мастеру публикации

## Этап 3: CI/CD Setup (GitHub Actions)

### Добавьте Secrets в GitHub

Repository Settings → Secrets and variables → Actions → New repository secret:

```
# Yandex API Keys
YANDEX_MAPKIT_API_KEY        = ваш_production_mapkit_ключ
YANDEX_GEOCODING_API_KEY     = ваш_production_geocoding_ключ

# Android Signing
ANDROID_KEYSTORE_BASE64      = base64_encoded_keystore
ANDROID_KEYSTORE_PASSWORD    = пароль_keystore
ANDROID_KEY_PASSWORD         = пароль_ключа
ANDROID_KEY_ALIAS            = upload
```

### Создайте Base64 keystore

```bash
# Конвертируйте keystore в base64
base64 upload-keystore.jks > keystore.base64.txt

# Скопируйте содержимое файла в GitHub Secret
cat keystore.base64.txt
```

### Workflows

Проект включает 2 готовых workflow:

1. **Android Build** (`.github/workflows/build-android.yml`)
   - Триггер: push в `main`, `develop` или manual dispatch
   - Собирает debug APK для PR, release для main
   - Сохраняет артефакты на 30 дней

2. **iOS Build** (`.github/workflows/build-ios.yml`)
   - Триггер: push в `main` или manual dispatch
   - Использует macOS runner (платный)
   - Собирает unsigned iOS app

### Запуск вручную

GitHub → Actions → выберите workflow → Run workflow → выберите branch

## Этап 4: Публикация в Store

### Google Play Console

1. Создайте приложение: https://play.google.com/console
2. Загрузите AAB в Production track
3. Заполните метаданные:
   - Название: AndexEvents
   - Описание: [из marketing materials]
   - Скриншоты: минимум 2 для каждого размера
   - Иконка: 512x512px

4. Настройте content rating и privacy policy
5. Отправьте на review

### Apple App Store

1. App Store Connect: https://appstoreconnect.apple.com
2. Создайте App ID через Certificates, Identifiers & Profiles
3. Загрузите build через Xcode или Transporter
4. Заполните метаданные в App Store Connect
5. Submit for Review

## Мониторинг Production

### Метрики для отслеживания

1. **Yandex API Usage**
   - Dashboard: https://developer.tech.yandex.ru/
   - Следите за квотами MapKit/Geocoding
   - Настройте уведомления о превышении лимитов

2. **Firebase Console**
   - Crashlytics: отслеживание крашей
   - Performance: время загрузки экранов
   - Analytics: активность пользователей

3. **Backend Health**
   - Docker containers status
   - Database connections
   - API response times
   - Error rates

### Логирование

Production логи должны:
- ❌ НЕ содержать API ключи
- ❌ НЕ содержать персональные данные пользователей
- ✅ Включать error stack traces
- ✅ Включать request IDs для трейсинга

## Rollback Plan

Если production build сломался:

1. **Немедленные действия:**
   ```bash
   # Откатите на предыдущий стабильный tag
   git checkout v1.2.3  # последний стабильный
   ./scripts/build-production.sh android
   ```

2. **В Google Play:**
   - Перейдите в Release management → App releases
   - Выберите production track → Halt rollout
   - Откатитесь на предыдущую версию

3. **В App Store:**
   - App Store Connect → версия → Remove from Sale
   - Или отправьте hotfix build с повышенным priority review

## Troubleshooting

### "API key not configured"

**Причина:** `--dart-define` не передан при сборке

**Решение:**
```bash
# Проверьте, что ключи загружены
cat secrets/yandex_mapkit_api_key.txt
cat secrets/yandex_geocode_api_key.txt

# Пересоберите с явными define
flutter build apk --release \
  --dart-define=YANDEX_MAPKIT_API_KEY=$(cat secrets/yandex_mapkit_api_key.txt) \
  --dart-define=YANDEX_API_KEY=$(cat secrets/yandex_geocode_api_key.txt)
```

### CI Build Failed: "Signing configuration missing"

**Причина:** GitHub Secrets не настроены

**Решение:**
1. Проверьте все secrets в Settings → Secrets
2. Убедитесь, что base64 ключ правильный:
   ```bash
   echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > test.jks
   keytool -list -keystore test.jks
   ```

### iOS Build: "Provisioning profile doesn't match"

**Причина:** Bundle ID не совпадает с profile

**Решение:**
1. Xcode → Signing & Capabilities
2. Убедитесь: Bundle Identifier = `com.andexevents.app`
3. Пересоздайте provisioning profile на developer.apple.com

## Чеклист перед Production Deploy

- [ ] Все тесты проходят (`flutter test`)
- [ ] API ключи production настроены
- [ ] Firebase production config установлен
- [ ] Android signed с production keystore
- [ ] iOS подписан с production certificate
- [ ] Privacy Policy URL актуален
- [ ] Backend API указывает на production
- [ ] Версия обновлена в `pubspec.yaml`
- [ ] Changelog заполнен
- [ ] Crashlytics/Analytics работают
- [ ] Smoke test на реальных устройствах
- [ ] Store listings подготовлены

## Контакты и Support

- **DevOps вопросы:** создайте issue в репозитории
- **Критические инциденты:** [emergency contact]
- **Мониторинг:** [monitoring dashboard URL]
