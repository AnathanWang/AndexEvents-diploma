# Firebase Configuration Setup

## ⚠️ ВАЖНО: Настройка Firebase ключей

Этот проект использует Firebase для аутентификации. **Firebase конфигурационные файлы НЕ включены в репозиторий** по соображениям безопасности.

## 📋 Шаги настройки

### 1. Получите Firebase конфигурационные файлы

Скачайте файлы из Firebase Console (https://console.firebase.google.com):

#### Для Android:
1. Откройте проект `andexevents` в Firebase Console
2. Перейдите в Project Settings → Your apps → Android app
3. Скачайте `google-services.json`
4. Поместите файл в: `android/app/google-services.json`

#### Для iOS:
1. Откройте проект `andexevents` в Firebase Console
2. Перейдите в Project Settings → Your apps → iOS app
3. Скачайте `GoogleService-Info.plist`
4. Поместите файл в: `ios/Runner/GoogleService-Info.plist`

### 2. Создайте firebase_options.dart

```bash
# Скопируйте пример файла
cp lib/firebase_options.dart.example lib/firebase_options.dart
```

Откройте `lib/firebase_options.dart` и замените:
- `YOUR_ANDROID_API_KEY` → на Android API Key из Firebase Console
- `YOUR_IOS_API_KEY` → на iOS API Key из Firebase Console

### 3. Проверьте .gitignore

Убедитесь что следующие файлы в `.gitignore`:
```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

## 🚫 НЕ КОММИТЬТЕ в Git:

- ❌ `lib/firebase_options.dart` (содержит API ключи)
- ❌ `android/app/google-services.json` (содержит Android конфиг)
- ❌ `ios/Runner/GoogleService-Info.plist` (содержит iOS конфиг)
- ✅ `lib/firebase_options.dart.example` (файл-шаблон без ключей)

## 🔐 Безопасность

### Firebase API Keys в клиентских приложениях

Firebase API ключи для клиентских приложений (Android/iOS) **не являются секретами** в традиционном смысле:
- Они встраиваются в APK/IPA файлы
- Они предназначены для публичного использования
- Безопасность обеспечивается через Firebase Security Rules и App Check

**Однако**, рекомендуется не хранить их в публичном репозитории:
1. Для предотвращения злоупотребления квотами Firebase
2. Для защиты от спама и bot-атак
3. Для соблюдения best practices

### Защита Firebase проекта

1. **Настройте Firebase Security Rules** для Firestore, Storage, и Realtime Database
2. **Включите App Check** для защиты от злоупотребления API
3. **Настройте ограничения для API ключей** в Google Cloud Console:
   - Ограничьте по bundle ID (iOS) и package name (Android)
   - Ограничьте по IP адресам (для серверных ключей)
4. **Мониторьте использование** в Firebase Console

## 📱 Где находятся API ключи?

### В Firebase Console:
1. Перейдите в Project Settings
2. Выберите нужное приложение (Android/iOS)
3. Найдите `Web API Key` в разделе конфигурации

### Или через CLI:
```bash
# Регенерация конфигурации через FlutterFire CLI
flutterfire configure
```

## 🔄 Ротация ключей

Если ключи были скомпрометированы:

1. **Удалите старые ключи** из Firebase Console:
   - Project Settings → Cloud Messaging → Server keys
   - API keys в Google Cloud Console

2. **Создайте новые ключи**

3. **Обновите все конфиг файлы**:
   - `lib/firebase_options.dart`
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

4. **НЕ коммитьте** файлы с новыми ключами!

## 🆘 Troubleshooting

### "DefaultFirebaseOptions have not been configured"
- Убедитесь что `lib/firebase_options.dart` существует и содержит правильные ключи

### "FirebaseOptions are not supported for this platform"
- Проверьте платформу в `firebase_options.dart`
- Добавьте конфигурацию для нужной платформы

### Builds fails with "google-services.json not found"
- Скачайте файл из Firebase Console
- Поместите в `android/app/google-services.json`

### iOS build fails with "GoogleService-Info.plist not found"
- Скачайте файл из Firebase Console
- Поместите в `ios/Runner/GoogleService-Info.plist`
- Убедитесь что файл добавлен в Xcode project (Runner target)

## 📚 Документация

- [Firebase для Flutter](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)
- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/security)
