# 🔥 Firebase Setup Guide - Быстрая настройка

## Шаг 1: Backend (.env файл)

После создания Service Account в Firebase Console, скачаете JSON файл и обновите `/backend/.env`:

```env
# Firebase Admin SDK
FIREBASE_PROJECT_ID="your-project-id"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour key here...\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com"

# ИЛИ используйте путь к JSON файлу:
FIREBASE_SERVICE_ACCOUNT_PATH="./firebase-service-account.json"
```

**ВАЖНО**: Если используете `FIREBASE_PRIVATE_KEY`, замените все `\n` в ключе на реальные переносы строк!

## Шаг 2: Flutter (firebase_config.dart)

Обновите `/lib/core/config/firebase_config.dart`:

```dart
class FirebaseConfig {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) {
      return ios;
    } else if (Platform.isAndroid) {
      return android;
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',              // ← Замените
    appId: '1:123456789:android:abcdef',         // ← Замените
    messagingSenderId: '123456789',              // ← Замените
    projectId: 'your-project-id',                // ← Замените
    storageBucket: 'your-project.appspot.com',   // ← Замените
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',                  // ← Замените
    appId: '1:123456789:ios:abcdef',             // ← Замените
    messagingSenderId: '123456789',              // ← Замените
    projectId: 'your-project-id',                // ← Замените
    storageBucket: 'your-project.appspot.com',   // ← Замените
    iosBundleId: 'com.andex.events',             // ← Ваш Bundle ID
  );
}
```

## Шаг 3: Добавить файлы конфигурации

### Android:
Скопируйте `google-services.json` в:
```
/android/app/google-services.json
```

### iOS:
Скопируйте `GoogleService-Info.plist` в:
```
/ios/Runner/GoogleService-Info.plist
```

## Шаг 4: Раскомментируйте Firebase в main.dart

Откройте `/lib/main.dart` и раскомментируйте:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Раскомментируйте это:
  await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const AndexApp());
}
```

## Шаг 5: Проверка

1. **Backend**: `npm start` - должен запуститься без ошибок
2. **Flutter**: `flutter run` - приложение должно запуститься

## 🔑 Где найти ключи?

**Firebase Console** → Your Project → ⚙️ Project Settings:

- **General tab**:
  - Project ID
  - Web API Key
  - App IDs (iOS/Android)
  - Sender ID

- **Service Accounts tab**:
  - Generate new private key → Download JSON

## ✅ Чеклист

- [ ] Service Account JSON скачан
- [ ] Backend `.env` обновлен
- [ ] Flutter `firebase_config.dart` обновлен
- [ ] `google-services.json` добавлен (Android)
- [ ] `GoogleService-Info.plist` добавлен (iOS)
- [ ] Firebase Authentication включен (Email/Password, Google)
- [ ] Firebase код раскомментирован в `main.dart`
- [ ] Backend запускается без ошибок
- [ ] Flutter приложение запускается

## 🚨 Частые ошибки

**Backend: "Failed to initialize Firebase"**
- Проверьте правильность ключей в `.env`
- Убедитесь что `FIREBASE_PRIVATE_KEY` содержит `\n` для переносов строк

**Flutter: "Firebase initialization failed"**
- Убедитесь что файлы `google-services.json` и `.plist` добавлены
- Проверьте правильность ключей в `firebase_config.dart`
- Очистите кеш: `flutter clean && flutter pub get`

**Auth не работает**
- Включите Email/Password authentication в Firebase Console
- Проверьте что SHA-1 fingerprint добавлен для Android
