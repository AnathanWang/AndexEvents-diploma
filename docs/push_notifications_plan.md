# План внедрения Push-уведомлений (FCM) в Andex Events

## 1. Обзор архитектуры
Для доставки уведомлений используется **Firebase Cloud Messaging (FCM)**.

**Поток данных:**
1.  **Frontend (Flutter):** Получает FCM-токен от Firebase при запуске.
2.  **Frontend:** Отправляет токен на Бэкенд (`POST /api/users/devices`).
3.  **Backend (Java Users Service):** Сохраняет токен в базе данных (связка `userId` — `fcmToken`).
4.  **Backend (Microservices):**
    *   `match-service` (Go): При совпадении отправляет уведомление через Firebase Admin SDK.
    *   `events-service` (Java): Отправляет напоминания о событиях.

---

## 2. Пошаговый план реализации

### Этап 1: Настройка Фронтенда (Flutter)

1.  **Зависимости:**
    *   Раскомментировать `firebase_messaging` в `pubspec.yaml`.
    *   Выполнить `flutter pub get`.

2.  **Инициализация (`main.dart`):**
    *   Настроить обработчик фоновых сообщений (`onBackgroundMessage`).
    *   Запросить разрешение на уведомления (`requestPermission`).
    *   Получить APNS/FCM токен.

3.  **Логика синхронизации токена:**
    *   В `UserService` (Dart) добавить метод `saveDeviceToken(String token)`.
    *   Вызывать этот метод:
        *   После успешного входа (Login).
        *   При старте приложения (если пользователь уже авторизован).
        *   При обновлении токена (`onTokenRefresh`).

4.  **Обработка нажатий:**
    *   Настроить `FirebaseMessaging.onMessageOpenedApp` для навигации (например, открытие профиля при мэтче).

### Этап 2: Бэкенд — Сервис Пользователей (Java)

1.  **База данных:**
    *   Создать таблицу `user_devices` (так как у одного юзера может быть и айфон, и андроид одновременно).
    *   Поля: `id`, `user_id`, `fcm_token`, `platform` (ios/android), `last_active`.

2.  **API Эндпоинт:**
    *   `POST /api/users/devices`
    *   Body: `{ "token": "...", "platform": "android" }`
    *   Логика: "Upsert" (если токен уже есть — обновить `last_active`, если нет — добавить).

### Этап 3: Бэкенд — Отправка уведомлений

#### Сценарий А: "Новый Мэтч" (Go Match Service)
Так как сервис матчей написан на Go:
1.  Подключить `firebase.google.com/go/v4`.
2.  Использовать `firebase-service-account.json`.
3.  Логика:
    *   Когда происходит `Match` (два лайка).
    *   Получить FCM-токены обоих пользователей (запрос в `users-service` или чтение из БД, если базы общие/реплицируемые).
    *   Отправить пуш: *"У вас взаимная симпатия! Посмотрите профиль..."*.

#### Сценарий Б: "Напоминание о событии" (Java Events Service)
1.  Подключить `firebase-admin` (Java SDK).
2.  Сделать Scheduled Task (Cron), который раз в час ищет события, начинающиеся скоро.
3.  Найти участников.
4.  Отправить пуш: *"Событие 'Йога в парке' начинается через 2 часа"*.

---

## 3. Необходимые изменения в файлах

### `pubspec.yaml`
```yaml
dependencies:
  firebase_messaging: ^15.1.3  # Раскомментировать
  flutter_local_notifications: ^18.0.0 # Опционально, для показа уведомлений, когда приложение открыто
```

### `lib/data/services/user_service.dart`
```dart
Future<void> syncDeviceToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  // Отправка на бэкенд...
}
```

### `backend/db/migrations` (Java/Flyway)
```sql
CREATE TABLE user_devices (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    token TEXT NOT NULL UNIQUE,
    platform VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 4. Контрольный список (Checklist)
- [ ] iOS: Добавлен Push Notification Capability в Xcode.
- [ ] iOS: Загружен APNs Key в Firebase Console.
- [ ] Android: Проверен `google-services.json`.
- [ ] Frontend: Токен получается и печатается в консоль.
- [ ] Backend: Токен сохраняется в БД.
- [ ] Тест: Отправка тестового пуша из Firebase Console по токену девайса.
