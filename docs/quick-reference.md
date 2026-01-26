# Andex Events - Краткая справка разработчика

## 🚀 Быстрый старт

### Запуск Backend

```bash
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

### Запуск Flutter

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

### Настройка Yandex MapKit

```bash
sh ./scripts/store_yandex_key.sh <YANDEX_MAPKIT_KEY> [YANDEX_GEOCODE_KEY]
```

---

## 📊 Модель данных (Prisma)

### Основные сущности

```
User ──1:N──> Event
User ──N:M──> Event (через Participant)
User ──N:M──> User (через Match)
User ──1:N──> Notification
```

### Enum типы

```typescript
UserRole: USER | MODERATOR | ADMIN
EventStatus: PENDING | APPROVED | REJECTED
MatchAction: LIKE | DISLIKE | SUPER_LIKE
ParticipantStatus: INTERESTED | GOING
```

---

## 🔐 Аутентификация

### Получение JWT токена (Flutter)

```dart
final token = await Supabase.instance.client.auth.currentSession?.accessToken;
```

### Верификация токена (Backend)

```typescript
const decoded = jwt.verify(token, process.env.SUPABASE_JWT_SECRET);
const user = await prisma.user.findUnique({ where: { supabaseUid: decoded.sub } });
```

### Защита endpoint'ов

```typescript
router.get('/api/users/me', authMiddleware, getCurrentUser);
```

---

## 📡 API Endpoints

### Пользователи

| Метод | Путь | Описание | Auth |
|-------|------|----------|------|
| POST | `/api/users` | Создать пользователя | ❌ |
| GET | `/api/users/me` | Получить текущего пользователя | ✅ |
| PUT | `/api/users/me` | Обновить профиль | ✅ |
| PUT | `/api/users/me/location` | Обновить геолокацию | ✅ |
| GET | `/api/users/matches` | Получить потенциальные матчи | ✅ |

### События

| Метод | Путь | Описание | Auth |
|-------|------|----------|------|
| GET | `/api/events` | Все события | ❌ |
| GET | `/api/events/nearby` | События рядом | ❌ |
| GET | `/api/events/:id` | Событие по ID | ❌ |
| POST | `/api/events` | Создать событие | ✅ |
| PUT | `/api/events/:id` | Обновить событие | ✅ |
| DELETE | `/api/events/:id` | Удалить событие | ✅ |
| POST | `/api/events/:id/participate` | Участвовать в событии | ✅ |
| DELETE | `/api/events/:id/participate` | Отменить участие | ✅ |

### Загрузка файлов

| Метод | Путь | Описание | Auth |
|-------|------|----------|------|
| POST | `/api/upload?bucket=avatars` | Загрузить аватар | ✅ |
| POST | `/api/upload?bucket=events` | Загрузить фото события | ✅ |

### Матчи

| Метод | Путь | Описание | Auth |
|-------|------|----------|------|
| POST | `/api/matches` | Создать матч (лайк/дизлайк) | ✅ |
| GET | `/api/matches/mutual` | Взаимные матчи | ✅ |

---

## 🗺️ PostGIS запросы

### Создание события с геоточкой

```sql
INSERT INTO "Event" (
  id, title, description, location,
  latitude, longitude, "locationGeo", ...
) VALUES (
  gen_random_uuid()::text,
  'Concert',
  'Description',
  'Moscow',
  55.7558,
  37.6173,
  ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography,
  ...
)
```

### Поиск событий в радиусе

```sql
SELECT
  e.*,
  ST_Distance(
    e."locationGeo",
    ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography
  ) as distance
FROM "Event" e
WHERE ST_DWithin(
  e."locationGeo",
  ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography,
  5000  -- радиус в метрах
)
ORDER BY distance ASC;
```

**Важно:** В `ST_MakePoint(lon, lat)` долгота идёт первой!

---

## 🖼️ Загрузка изображений

### Flutter → Supabase Storage

```dart
// 1. Сжатие
final compressed = await ImageUtils.compressImage(file);

// 2. Загрузка
final path = 'events/${DateTime.now().millisecondsSinceEpoch}';
await Supabase.instance.client.storage
  .from('events')
  .uploadBinary(
    path,
    await compressed.readAsBytes(),
    fileOptions: FileOptions(contentType: 'image/jpeg'),
  );

// 3. Получение URL
final url = Supabase.instance.client.storage
  .from('events')
  .getPublicUrl(path);
```

### Flutter → Backend (Multer)

```dart
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(filePath),
});

final response = await dio.post(
  '/api/upload?bucket=events',
  data: formData,
  options: Options(
    headers: {'Authorization': 'Bearer $token'},
  ),
);

final imageUrl = response.data['fileUrl'];
```

---

## 🎨 BLoC Pattern

### Создание Bloc

```dart
class EventBloc extends Bloc<EventEvent, EventState> {
  final EventService _eventService;

  EventBloc(this._eventService) : super(EventInitial()) {
    on<LoadEvents>(_onLoadEvents);
    on<CreateEvent>(_onCreateEvent);
  }

  Future<void> _onLoadEvents(LoadEvents event, Emitter<EventState> emit) async {
    emit(EventLoading());
    try {
      final events = await _eventService.getAllEvents();
      emit(EventLoaded(events: events));
    } catch (e) {
      emit(EventError(message: e.toString()));
    }
  }
}
```

### Использование в UI

```dart
BlocBuilder<EventBloc, EventState>(
  builder: (context, state) {
    if (state is EventLoading) {
      return CircularProgressIndicator();
    } else if (state is EventLoaded) {
      return ListView.builder(
        itemCount: state.events.length,
        itemBuilder: (context, index) => EventCard(state.events[index]),
      );
    } else if (state is EventError) {
      return Text('Error: ${state.message}');
    }
    return SizedBox();
  },
)
```

---

## 🔧 Prisma CLI команды

```bash
# Генерация Prisma Client
npx prisma generate

# Создание миграции
npx prisma migrate dev --name add_user_location

# Применение миграций
npx prisma migrate deploy

# Просмотр БД в браузере
npx prisma studio

# Форматирование schema.prisma
npx prisma format

# Валидация схемы
npx prisma validate

# Сброс БД (ОСТОРОЖНО!)
npx prisma migrate reset
```

---

## 📦 Переменные окружения

### Backend (.env)

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/andexevents?schema=public"

# Supabase
SUPABASE_URL="https://xxx.supabase.co"
SUPABASE_ANON_KEY="eyJ..."
SUPABASE_JWT_SECRET="your-jwt-secret"

# Yandex Maps
YANDEX_MAPS_API_KEY="your-key"

# Server
PORT=3000
NODE_ENV=development
```

### Flutter (--dart-define)

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.10:3000/api \
  --dart-define=YANDEX_MAPKIT_API_KEY=your-key
```

---

## 🐛 Отладка

### Backend логи

```typescript
import logger from './utils/logger.js';

logger.info('Info message', { userId: '123', action: 'login' });
logger.warn('Warning message');
logger.error('Error message', { error: err.stack });
```

### Flutter логи

```dart
print('🔵 [Service] Info message');
print('🟢 [Service] Success');
print('🔴 [Service] Error: $error');
```

### Просмотр логов Backend

```bash
tail -f backend/logs/combined.log
tail -f backend/logs/error.log
```

---

## 🧪 Тестирование API

### cURL примеры

```bash
# Создать пользователя
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "supabaseUid": "123",
    "email": "user@example.com",
    "displayName": "John Doe"
  }'

# Получить события рядом
curl "http://localhost:3000/api/events/nearby?lat=55.7558&lon=37.6173&radius=5000"

# Создать событие (с токеном)
curl -X POST http://localhost:3000/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "Concert",
    "description": "Rock concert",
    "category": "music",
    "location": "Moscow",
    "latitude": 55.7558,
    "longitude": 37.6173,
    "dateTime": "2024-12-31T20:00:00Z",
    "price": 1000
  }'
```

---

## 📱 Flutter команды

```bash
# Установка зависимостей
flutter pub get

# Запуск на эмуляторе/устройстве
flutter run

# Запуск с конкретным устройством
flutter run -d <device-id>

# Список устройств
flutter devices

# Очистка кэша
flutter clean

# Обновление зависимостей
flutter pub upgrade

# Анализ кода
flutter analyze

# Форматирование кода
dart format lib/

# Сборка APK (Android)
flutter build apk --release

# Сборка IPA (iOS)
flutter build ios --release
```

---

## 🗄️ Полезные SQL запросы

### Статистика пользователей

```sql
SELECT 
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE "isOnboardingCompleted" = true) as completed_onboarding,
  COUNT(*) FILTER (WHERE role = 'ADMIN') as admins
FROM "User";
```

### Популярные категории событий

```sql
SELECT 
  category,
  COUNT(*) as event_count,
  AVG(price) as avg_price
FROM "Event"
WHERE status = 'APPROVED'
GROUP BY category
ORDER BY event_count DESC;
```

### События с наибольшим количеством участников

```sql
SELECT 
  e.title,
  e."dateTime",
  COUNT(p.id) as participant_count
FROM "Event" e
LEFT JOIN "Participant" p ON e.id = p."eventId"
WHERE e.status = 'APPROVED'
GROUP BY e.id, e.title, e."dateTime"
ORDER BY participant_count DESC
LIMIT 10;
```

### Активность пользователей (матчи)

```sql
SELECT 
  u."displayName",
  u.email,
  COUNT(DISTINCT m1.id) as outgoing_matches,
  COUNT(DISTINCT m2.id) as incoming_matches,
  COUNT(DISTINCT CASE WHEN m1."isMutual" = true THEN m1.id END) as mutual_matches
FROM "User" u
LEFT JOIN "Match" m1 ON u.id = m1."userAId"
LEFT JOIN "Match" m2 ON u.id = m2."userBId"
GROUP BY u.id, u."displayName", u.email
ORDER BY mutual_matches DESC
LIMIT 20;
```

---

## 🔒 Безопасность - Чеклист

### Backend

- [x] Helmet.js для безопасных HTTP заголовков
- [x] CORS настроен
- [x] Rate limiting на auth и upload endpoints
- [x] JWT верификация
- [x] Параметризованные SQL запросы (Prisma)
- [x] Валидация входных данных (Zod)
- [x] Санитизация имён файлов
- [x] Проверка MIME типов и магических байтов
- [x] Защита от Path Traversal
- [x] HTTPS в production
- [ ] 2FA (планируется)
- [ ] Audit logging (планируется)

### Frontend

- [x] Secure Storage для токенов
- [x] HTTPS only в production
- [x] Валидация форм
- [x] Обработка ошибок без утечки данных
- [ ] Certificate pinning (планируется)
- [ ] Code obfuscation для release builds (планируется)

---

## 🚨 Распространённые проблемы

### "Cannot connect to localhost:3000" на физическом устройстве

**Решение:** Используйте IP адрес компьютера:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

### "SUPABASE_JWT_SECRET is not defined"

**Решение:** Добавьте в `backend/.env`:

```env
SUPABASE_JWT_SECRET=your-secret-from-supabase-dashboard
```

Найти в: Supabase Dashboard → Settings → API → JWT Secret

### PostGIS функции не работают

**Решение:** Убедитесь что расширение установлено:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### "Token expired" ошибка

**Решение:** Обновите токен через Supabase:

```dart
await Supabase.instance.client.auth.refreshSession();
final newToken = Supabase.instance.client.auth.currentSession?.accessToken;
```

### Prisma Client не синхронизирован со схемой

**Решение:**

```bash
npx prisma generate
```

### Flutter "MissingPluginException"

**Решение:**

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

---

## 📚 Дополнительные ресурсы

### Документация

- [Prisma Docs](https://www.prisma.io/docs)
- [PostGIS Manual](https://postgis.net/docs/)
- [Flutter BLoC](https://bloclibrary.dev/)
- [Supabase Docs](https://supabase.io/docs)
- [Yandex MapKit](https://yandex.ru/dev/mapkit/doc/)

### Полезные ссылки

- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Express Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
- [Flutter Performance](https://docs.flutter.dev/perf)

---

## 🎯 Roadmap / TODO

### Backend

- [ ] WebSocket для реалтайм обновлений
- [ ] Redis кеширование
- [ ] Elasticsearch для поиска событий
- [ ] Firebase Cloud Messaging (FCM) для push
- [ ] Unit и Integration тесты
- [ ] Docker Compose для dev окружения
- [ ] CI/CD pipeline (GitHub Actions)

### Frontend

- [ ] Чаты между матчами
- [ ] Отзывы о событиях
- [ ] Расширенные фильтры поиска
- [ ] Темная тема
- [ ] Multilanguage support (i18n)
- [ ] Offline mode с синхронизацией
- [ ] Widget тесты
- [ ] E2E тесты (integration_test)

### Infrastructure

- [ ] Kubernetes deployment
- [ ] Horizontal scaling
- [ ] Database read replicas
- [ ] Monitoring (Prometheus + Grafana)
- [ ] Error tracking (Sentry)
- [ ] CDN для статики

---

**Последнее обновление:** 2024-12-13