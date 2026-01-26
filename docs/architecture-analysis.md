# Andex Events - Полный анализ архитектуры и проектирования

## 📋 Оглавление

1. [Обзор проекта](#обзор-проекта)
2. [Модель данных](#модель-данных)
3. [Система хранения изображений](#система-хранения-изображений)
4. [Аутентификация и авторизация](#аутентификация-и-авторизация)
5. [Backend архитектура](#backend-архитектура)
6. [Frontend архитектура](#frontend-архитектура)
7. [Геолокация и карты](#геолокация-и-карты)
8. [Безопасность](#безопасность)
9. [Рекомендации по улучшению](#рекомендации-по-улучшению)

---

## Обзор проекта

**Andex Events** — это мобильное приложение для поиска событий и знакомств с единомышленниками, построенное на современном tech stack.

### Технологический стек

#### Frontend (Mobile)
- **Flutter** 3.9.2+ / Dart 3.9.2+
- **State Management**: BLoC (flutter_bloc ^8.1.6)
- **UI Framework**: Material Design 3
- **Карты**: Yandex MapKit 4.1.0
- **Геолокация**: geolocator ^13.0.1
- **Аутентификация**: Supabase Flutter ^2.6.0
- **HTTP клиент**: Dio ^5.7.0
- **Хранение**: shared_preferences, flutter_secure_storage

#### Backend (API)
- **Runtime**: Node.js + TypeScript
- **Framework**: Express.js 5.1.0
- **ORM**: Prisma 6.19.0
- **База данных**: PostgreSQL + PostGIS расширение
- **Аутентификация**: JWT (jsonwebtoken ^9.0.2)
- **Загрузка файлов**: Multer ^1.4.5
- **Обработка изображений**: Sharp ^0.33.5
- **Валидация**: Zod ^4.1.12
- **Логирование**: Winston ^3.15.0

#### Аутентификация и Storage
- **Supabase** (Auth + Storage)
  - URL: `https://rykbewslbfxltmipyseg.supabase.co`
  - Используется для OAuth провайдеров и хранения изображений

---

## Модель данных

### Prisma Schema

Проект использует **Prisma ORM** с PostgreSQL и расширением PostGIS для работы с геоданными.

```prisma
datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  extensions = [postgis]
}

generator client {
  provider        = "prisma-client-js"
  output          = "../src/generated/prisma"
  previewFeatures = ["postgresqlExtensions"]
}
```

### Основные сущности

#### 1. User (Пользователь)

```typescript
model User {
  id            String   @id @default(uuid())
  supabaseUid   String   @unique        // ID из Supabase Auth
  email         String   @unique
  displayName   String?
  photoUrl      String?
  bio           String?
  interests     String[]                // Массив интересов
  socialLinks   Json?                   // {instagram, telegram, etc}
  age           Int?
  gender        String?
  role          UserRole @default(USER) // USER | MODERATOR | ADMIN
  
  // Геолокация
  lastLatitude  Float?
  lastLongitude Float?
  lastLocationUpdate DateTime?
  
  // Настройки приватности
  isProfileVisible   Boolean @default(true)
  isLocationVisible  Boolean @default(true)
  minAge             Int?
  maxAge             Int?
  maxDistance        Int @default(50000)  // В метрах
  
  // FCM токен для push-уведомлений
  fcmToken      String?
  
  // Онбординг
  isOnboardingCompleted Boolean @default(false)
  
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  
  // Отношения
  createdEvents         Event[] @relation("EventCreator")
  participations        Participant[]
  matchesAsUserA        Match[] @relation("MatchUserA")
  matchesAsUserB        Match[] @relation("MatchUserB")
  sentNotifications     Notification[] @relation("NotificationSender")
  receivedNotifications Notification[] @relation("NotificationReceiver")
}
```

**Ключевые особенности модели User:**

- **supabaseUid**: Связь с системой аутентификации Supabase
- **interests**: Массив строк для быстрого матчинга по интересам
- **socialLinks**: JSON поле для гибкого хранения различных социальных сетей
- **Геолокация**: Хранение последних координат для поиска ближайших событий и пользователей
- **Настройки приватности**: Контроль видимости профиля и локации
- **Возрастные фильтры**: minAge/maxAge для матчинга
- **maxDistance**: Радиус поиска в метрах (по умолчанию 50 км)

#### 2. Event (Событие)

```typescript
model Event {
  id          String   @id @default(uuid())
  title       String
  description String   @db.Text
  category    String
  
  // Геолокация с PostGIS
  location    String   // Адрес (текстовый)
  latitude    Float
  longitude   Float
  locationGeo Unsupported("geography(Point, 4326)")? // PostGIS точка
  
  dateTime    DateTime
  endDateTime DateTime?
  price       Float    @default(0)
  imageUrl    String?
  isOnline    Boolean  @default(false)
  
  // Модерация
  status      EventStatus @default(PENDING)  // PENDING | APPROVED | REJECTED
  rejectionReason String?
  
  // Ограничения
  maxParticipants Int?
  minAge      Int?
  maxAge      Int?
  
  createdById String?
  createdBy   User? @relation("EventCreator", fields: [createdById], references: [id], onDelete: Cascade)
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  participants Participant[]
}
```

**Ключевые особенности модели Event:**

- **PostGIS Geography**: Поле `locationGeo` использует тип `geography(Point, 4326)` для эффективных геопространственных запросов
- **Модерация**: Трёхступенчатый статус (PENDING → APPROVED/REJECTED)
- **Гибкие ограничения**: Можно установить минимальный/максимальный возраст, лимит участников
- **Онлайн события**: Флаг `isOnline` для виртуальных мероприятий
- **Каскадное удаление**: При удалении пользователя удаляются его события

#### 3. Participant (Участник события)

```typescript
model Participant {
  id        String   @id @default(uuid())
  
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  eventId   String
  event     Event    @relation(fields: [eventId], references: [id], onDelete: Cascade)
  
  status    ParticipantStatus @default(INTERESTED)  // INTERESTED | GOING
  
  joinedAt  DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@unique([userId, eventId])
  @@index([userId])
  @@index([eventId])
}
```

**Ключевые особенности:**

- **Уникальная связь**: Композитный уникальный ключ `(userId, eventId)` — один пользователь может участвовать в событии только один раз
- **Статус участия**: INTERESTED (интересуюсь) vs GOING (точно иду)
- **Индексы**: Для быстрого поиска участников по пользователю или событию

#### 4. Match (Матчинг пользователей)

```typescript
model Match {
  id        String   @id @default(uuid())
  
  userAId   String
  userA     User     @relation("MatchUserA", fields: [userAId], references: [id], onDelete: Cascade)
  
  userBId   String
  userB     User     @relation("MatchUserB", fields: [userBId], references: [id], onDelete: Cascade)
  
  userAAction MatchAction?  // LIKE | DISLIKE | SUPER_LIKE
  userBAction MatchAction?
  
  isMutual  Boolean  @default(false)
  matchedAt DateTime?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@unique([userAId, userBId])
  @@index([userAId])
  @@index([userBId])
  @@index([isMutual])
}
```

**Ключевые особенности:**

- **Двунаправленный матчинг**: Хранятся действия обоих пользователей
- **Типы действий**: LIKE, DISLIKE, SUPER_LIKE
- **Флаг isMutual**: Автоматически устанавливается при взаимном лайке
- **Tinder-style механика**: Свайп влево/вправо

#### 5. Notification (Уведомления)

```typescript
model Notification {
  id          String   @id @default(uuid())
  
  type        String   // MATCH, EVENT_REMINDER, EVENT_APPROVED, etc.
  title       String
  body        String   @db.Text
  data        Json?    // Дополнительные данные
  
  senderId    String?
  sender      User?    @relation("NotificationSender", fields: [senderId], references: [id], onDelete: SetNull)
  
  receiverId  String
  receiver    User     @relation("NotificationReceiver", fields: [receiverId], references: [id], onDelete: Cascade)
  
  isRead      Boolean  @default(false)
  
  createdAt   DateTime @default(now())
  
  @@index([receiverId])
  @@index([isRead])
  @@index([type])
}
```

**Ключевые особенности:**

- **Типизированные уведомления**: Различные типы (матчи, напоминания, одобрения)
- **JSON данные**: Гибкое хранение дополнительной информации
- **Статус прочтения**: Отслеживание непрочитанных уведомлений
- **Индексы**: Для быстрой фильтрации по получателю, статусу и типу

### Enums

```typescript
enum UserRole {
  USER
  MODERATOR
  ADMIN
}

enum EventStatus {
  PENDING    // Ожидает модерации
  APPROVED   // Одобрено
  REJECTED   // Отклонено
}

enum MatchAction {
  LIKE
  DISLIKE
  SUPER_LIKE
}

enum ParticipantStatus {
  INTERESTED  // Интересуюсь
  GOING       // Точно пойду
}
```

### Индексы базы данных

Проект использует следующие индексы для оптимизации запросов:

**User:**
- `supabaseUid` (unique)
- `email` (unique)

**Event:**
- `createdById`
- `status`
- `dateTime`
- `category`

**Participant:**
- `userId`
- `eventId`
- Композитный уникальный индекс `(userId, eventId)`

**Match:**
- `userAId`
- `userBId`
- `isMutual`
- Композитный уникальный индекс `(userAId, userBId)`

**Notification:**
- `receiverId`
- `isRead`
- `type`

---

## Система хранения изображений

Проект использует **гибридный подход** к хранению изображений:

### 1. Supabase Storage (Рекомендуемый вариант)

#### Структура бакетов

```
Supabase Storage
├── avatars/        (Public bucket)
│   └── {userId}/{timestamp}.jpg
└── events/         (Public bucket)
    └── {userId}/{timestamp}.jpg
```

#### Конфигурация

**Настройки бакетов:**
- **Права доступа**: Public (анонимное чтение)
- **Максимальный размер**: 
  - Аватары: 5 MB
  - События: 10 MB
- **Разрешённые форматы**: JPEG, PNG, GIF, WebP

#### Процесс загрузки (Flutter)

```dart
// lib/data/services/upload_service.dart
class ProgressUploadService {
  Future<String> uploadProfilePhoto(String filePath) async {
    // 1. Сжатие изображения
    final compressedFile = await ImageUtils.compressImage(originalFile);
    
    // 2. Проверка размера
    final fileSize = await compressedFile.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Файл слишком большой');
    }
    
    // 3. Генерация уникального имени
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final path = 'avatars/$fileName';
    
    // 4. Загрузка в Supabase Storage
    await _supabase.storage.from('avatars').uploadBinary(
      path,
      fileBytes,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    
    // 5. Получение публичного URL
    final url = _supabase.storage.from('avatars').getPublicUrl(path);
    return url;
  }
}
```

#### Оптимизация изображений

```dart
// lib/core/utils/image_utils.dart
class ImageUtils {
  static Future<File> compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,              // 70% качество
      minWidth: 512,            // Минимум 512px
      minHeight: 512,
      format: CompressFormat.jpeg,
    );
    return result;
  }
}
```

**Результаты сжатия:**
- Оригинал: 2-5 MB
- После сжатия: 200-800 KB (события), 100-300 KB (аватары)

### 2. Локальное хранилище (Альтернативный вариант)

Документация: `docs/local-storage-guide.md`

#### Структура директорий

```
App Documents Directory
└── storage/
    ├── avatars/
    │   ├── 1702390123456.jpg
    │   └── 1702390124567.jpg
    └── events/
        ├── 1702390126789.jpg
        └── 1702390127890.jpg
```

#### Преимущества и недостатки

**✅ Преимущества:**
- Нет зависимости от интернета
- Быстрое открытие фото
- Нет проблем с кешированием
- Полный контроль над файлами

**⚠️ Недостатки:**
- Нет облачного бэкапа
- Потеря данных при удалении приложения
- Нет синхронизации между устройствами
- Больше памяти на устройстве

### 3. Backend локальное хранилище (Node.js)

Backend также поддерживает загрузку файлов на сервер.

#### Структура директорий на сервере

```
backend/public/uploads/
├── avatars/
│   └── {userId}/
│       └── {timestamp}-{random}.jpg
└── events/
    └── {userId}/
        └── {timestamp}-{random}.jpg
```

#### Middleware для загрузки

```typescript
// backend/src/routes/upload.routes.ts
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const bucket = req.query.bucket || 'events';
    const userId = req.user?.userId;
    const uploadDir = path.join(process.cwd(), `public/uploads/${bucket}/${userId}`);
    
    // Создаём директорию
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(4).toString('hex');
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 },  // 10MB
  fileFilter: (req, file, cb) => {
    // Валидация MIME type и расширения
    const isValidImage = file.mimetype.startsWith('image/');
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    
    if (isValidImage && validExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});
```

#### Безопасность загрузки файлов

**1. Валидация MIME type**
```typescript
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
]);
```

**2. Проверка магических чисел (File Signatures)**
```typescript
const FILE_SIGNATURES = {
  jpeg: Buffer.from([0xFF, 0xD8, 0xFF]),
  png: Buffer.from([0x89, 0x50, 0x4E, 0x47]),
  gif: Buffer.from([0x47, 0x49, 0x46]),
  webp: Buffer.from([0x52, 0x49, 0x46, 0x46])
};

function validateFileSignature(buffer: Buffer, mimeType: string): boolean {
  if (mimeType === 'image/jpeg') {
    return buffer.subarray(0, 3).equals(FILE_SIGNATURES.jpeg);
  }
  // ... другие типы
}
```

**3. Санитизация имени файла (Path Traversal защита)**
```typescript
function sanitizeFilename(filename: string): string {
  return filename
    .replaceAll('..', '')           // Удаляем ..
    .replaceAll(/[/\\]/g, '')       // Удаляем слэши
    .replaceAll(/[^\w\s.-]/g, '')   // Только безопасные символы
    .trim();
}
```

**4. Middleware защиты доступа к файлам**
```typescript
// backend/src/middleware/file-access.middleware.ts
export const fileAccessMiddleware = (req, res, next) => {
  // GET запросы - разрешаем всем (публичные файлы)
  if (req.method === 'GET') {
    // Проверка на Path Traversal
    if (req.path.includes('..') || req.path.includes('//')) {
      return res.status(400).json({ message: 'Invalid file path' });
    }
    return next();
  }

  // POST/PUT/DELETE - требуют авторизации
  const authenticatedUserId = req.user?.userId;
  if (!authenticatedUserId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  // Извлекаем userId из пути: /uploads/{bucket}/{userId}/{filename}
  const parts = req.path.split('/').filter(Boolean);
  const [bucket, fileUserId] = parts;
  
  // Блокируем доступ к чужим файлам
  if (fileUserId !== authenticatedUserId) {
    logger.error('[FileAccess] Несанкционированный доступ', {
      authenticatedUserId,
      attemptedFileUserId: fileUserId,
    });
    return res.status(403).json({ message: 'Access denied' });
  }

  next();
};
```

### Обработка изображений (Sharp)

Backend использует **Sharp** для обработки изображений:

```typescript
import sharp from 'sharp';

// Изменение размера и оптимизация
await sharp(inputPath)
  .resize(1200, 1200, {
    fit: 'inside',
    withoutEnlargement: true
  })
  .jpeg({ quality: 80 })
  .toFile(outputPath);
```

### Rate Limiting для загрузок

```typescript
const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,  // 1 минута
  max: 10,              // максимум 10 загрузок
  message: 'Слишком много загрузок. Пожалуйста, подождите.',
});

app.use('/api/upload', uploadLimiter, uploadRoutes);
```

---

## Аутентификация и авторизация

### Архитектура аутентификации

Проект использует **Supabase Auth** + **JWT токены** для аутентификации.

```
┌─────────────────┐
│  Flutter App    │
└────────┬────────┘
         │ 1. signIn()
         ▼
┌─────────────────┐
│  Supabase Auth  │ ◄─── OAuth Providers (Google, Apple)
└────────┬────────┘
         │ 2. JWT Token
         ▼
┌─────────────────┐
│   Backend API   │
│  (JWT Verify)   │
└─────────────────┘
```

### 1. Supabase Authentication

#### Настройка клиента

```dart
// lib/main.dart
await Supabase.initialize(
  url: AppConfig.supabaseUrl,
  anonKey: AppConfig.supabaseAnonKey,
);
```

#### Методы аутентификации

**1. Email/Password регистрация**
```dart
// lib/data/services/auth_service.dart
Future<AuthResponse> signUpWithEmail({
  required String email,
  required String password,
  required String displayName,
}) async {
  // Создаём пользователя в Supabase
  final response = await _supabase.auth.signUp(
    email: email,
    password: password,
    data: {'display_name': displayName},
  );
  
  // Создаём пользователя в нашей БД
  if (response.user != null) {
    await _createUserInBackend(
      supabaseUid: response.user!.id,
      email: email,
      displayName: displayName,
    );
  }
  
  return response;
}
```

**2. Email/Password вход**
```dart
Future<AuthResponse> signInWithEmail({
  required String email,
  required String password,
}) async {
  return await _supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
}
```

**3. Google Sign-In**
```dart
Future<Map<String, dynamic>> signInWithGoogleAndGetStatus() async {
  // 1. Получаем Google аккаунт
  final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  
  // 2. Получаем токены
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  
  // 3. Входим в Supabase с Google токенами
  final AuthResponse response = await _supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: googleAuth.idToken!,
    accessToken: googleAuth.accessToken,
  );
  
  // 4. Создаём/обновляем пользователя в backend
  await _createUserInBackend(
    supabaseUid: response.user!.id,
    email: response.user!.email!,
    displayName: response.user!.userMetadata?['full_name'],
    photoUrl: response.user!.userMetadata?['avatar_url'],
  );
  
  return {
    'userCredential': response,
    'isOnboardingCompleted': await _getOnboardingStatus(),
  };
}
```

**4. Apple Sign-In**
Аналогично Google, но используя `OAuthProvider.apple`.

#### Получение JWT токена

```dart
Future<String?> getIdToken() async {
  return _supabase.auth.currentSession?.accessToken;
}
```

### 2. Backend JWT Verification

#### Auth Middleware

```typescript
// backend/src/middleware/auth.middleware.ts
export const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token provided' });
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    // Верифицируем JWT токен от Supabase
    const jwtSecret = process.env.SUPABASE_JWT_SECRET;
    const decoded = jwt.verify(token, jwtSecret) as JwtPayload;
    
    // Находим пользователя в БД по supabaseUid
    const user = await prisma.user.findUnique({
      where: { supabaseUid: decoded.sub }
    });
    
    // Сохраняем данные пользователя в request
    req.user = {
      uid: decoded.sub!,
      userId: user?.id,
      email: decoded.email,
    };
    
    next();
  } catch (error) {
    res.status(401).json({ message: 'Invalid token' });
  }
};
```

#### Опциональная аутентификация

```typescript
export const optionalAuthMiddleware = async (req, res, next) => {
  // Аналогично authMiddleware, но не блокирует запрос при отсутствии токена
  try {
    // ... проверка токена ...
    req.user = { /* ... */ };
  } catch (error) {
    // Игнорируем ошибку
  }
  next();
};
```

### 3. Создание пользователя в Backend

При регистрации через Supabase создаётся пользователь в собственной БД:

```typescript
// backend/src/controllers/user.controller.ts
export async function createUser(req, res) {
  const { supabaseUid, email, displayName, photoUrl } = req.body;
  
  // Проверка дубликатов
  const existingUser = await prisma.user.findUnique({
    where: { email }
  });
  
  if (existingUser) {
    if (!existingUser.supabaseUid) {
      // Обновляем существующего пользователя
      return await prisma.user.update({
        where: { id: existingUser.id },
        data: { supabaseUid }
      });
    }
    throw new Error('User with this email already exists');
  }
  
  // Создаём нового пользователя
  const newUser = await prisma.user.create({
    data: {
      supabaseUid,
      email,
      displayName: displayName || '',
      photoUrl: photoUrl || '',
    }
  });
  
  // Создаём папки для файлов пользователя
  createUserStorageFolders(newUser.id);
  
  return newUser;
}
```

### 4. Защита API endpoints

```typescript
// backend/src/routes/user.routes.ts
const router = Router();

// Публичный endpoint
router.post('/', createUser);

// Защищённые endpoints
router.get('/me', authMiddleware, getCurrentUser);
router.put('/me', authMiddleware, updateProfile);
router.put('/me/location', authMiddleware, updateLocation);
router.get('/matches', authMiddleware, getMatches);
```

### 5. Обработка ошибок аутентификации

```dart
// lib/data/services/auth_service.dart
String _handleSupabaseAuthException(AuthException e) {
  final message = e.message.toLowerCase();
  
  if (message.contains('invalid') && message.contains('email')) {
    return 'Некорректный формат email';
  }
  if (message.contains('user already registered')) {
    return 'Пользователь с таким email уже зарегистрирован';
  }
  if (message.contains('invalid login credentials')) {
    return 'Неверный email или пароль';
  }
  if (message.contains('email not confirmed')) {
    return 'Email не подтверждён. Проверьте почту';
  }
  
  return 'Ошибка авторизации: ${e.message}';
}
```

### 6. Онбординг и статус завершения

```dart
Future<Map<String, dynamic>> signInWithGoogleAndGetStatus() async {
  // ... вход через Google ...
  
  // Получаем статус онбординга из backend
  bool isOnboardingCompleted = false;
  try {
    final profileData = await getCurrentUserProfile();
    isOnboardingCompleted = profileData['isOnboardingCompleted'] ?? false;
  } catch (e) {
    isOnboardingCompleted = false;
  }
  
  return {
    'userCredential': response,
    'isOnboardingCompleted': isOnboardingCompleted,
  };
}
```

### 7. Обновление профиля и завершение онбординга

```typescript
// backend/src/controllers/user.controller.ts
export async function updateProfile(req, res) {
  const userId = req.user?.userId;
  
  const {
    displayName,
    bio,
    age,
    gender,
    interests,
    socialLinks,
    isOnboardingCompleted  // ← Флаг завершения онбординга
  } = req.body;
  
  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: {
      displayName,
      bio,
      age,
      gender,
      interests,
      socialLinks,
      isOnboardingCompleted
    }
  });
  
  return res.json({ success: true, data: updatedUser });
}
```

### 8. Роли и права доступа

```typescript
enum UserRole {
  USER       // Обычный пользователь
  MODERATOR  // Может модерировать события
  ADMIN      // Полный доступ
}

// Middleware проверки роли
export const requireRole = (roles: UserRole[]) => {
  return async (req, res, next) => {
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId }
    });
    
    if (!user || !roles.includes(user.role)) {
      return res.status(403).json({ message: 'Forbidden' });
    }
    
    next();
  };
};

// Использование
router.put('/events/:id/approve', authMiddleware, requireRole(['MODERATOR', 'ADMIN']), approveEvent);
```

---

## Backend архитектура

### Структура проекта

```
backend/
├── prisma/
│   ├── schema.prisma           # Prisma схема
│   └── migrations/             # Миграции БД
├── src/
│   ├── controllers/            # Контроллеры (бизнес-логика)
│   │   ├── event.controller.ts
│   │   ├── user.controller.ts
│   │   ├── match.controller.ts
│   │   └── upload.controller.ts
│   ├── routes/                 # Маршруты API
│   │   ├── event.routes.ts
│   │   ├── user.routes.ts
│   │   ├── match.routes.ts
│   │   └── upload.routes.ts
│   ├── services/               # Сервисы (работа с БД)
│   │   ├── event.service.ts
│   │   ├── user.service.ts
│   │   └── match.service.ts
│   ├── middleware/             # Middleware
│   │   ├── auth.middleware.ts
│   │   └── file-access.middleware.ts
│   ├── utils/                  # Утилиты
│   │   ├── logger.ts
│   │   ├── prisma.ts
│   │   ├── geocoding.ts
│   │   └── user-storage.ts
│   └── index.ts                # Точка входа
├── public/
│   └── uploads/                # Загруженные файлы
│       ├── avatars/
│       └── events/
├── package.json
└── tsconfig.json
```

### Слоистая архитектура

```
┌─────────────────────────────────────┐
│         HTTP Request                │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Middleware Layer            │
│  - Authentication                   │
│  - Rate Limiting                    │
│  - Logging                          │
│  - File Access Control              │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Routes Layer                │
│  - URL Mapping                      │
│  - Request Validation               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Controllers Layer             │
│  - Request/Response handling        │
│  - Input validation                 │
│  - Error handling                   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│        Services Layer               │
│  - Business logic                   │
│  - Database operations (Prisma)     │
│  - External API calls               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Database (PostgreSQL)         │
└─────────────────────────────────────┘
```

### Ключевые компоненты

#### 1. Express Server

```typescript
// src/index.ts
const app = express();

// Security middleware
app.use(helmet());
app.use(cors());

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

// Rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 минут
  max: 100,                   // 100 запросов
});
app.use(generalLimiter);

// Routes
app.use('/api/events', eventRoutes);
app.use('/api/users', userRoutes);
app.use('/api/matches', matchRoutes);
app.use('/api/upload', uploadLimiter, uploadRoutes);

// Static files
app.use('/uploads', fileAccessMiddleware);
app.use('/uploads', express.static(path.join(process.cwd(), 'public/uploads')));
```

#### 2. Логирование (Winston)

```typescript
// src/utils/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
  ],
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}
```

#### 3. Rate Limiting

```typescript
// src/index.ts
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 минут
  max: 5,                     // 5 попыток
  message: 'Слишком много попыток входа. Попробуйте позже.',
});

const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,  // 1 минута
  max: 10,              // 10 загрузок
  message: 'Слишком много загрузок. Подождите.',
});

app.use('/api/users/login', authLimiter);
app.use('/api/upload', uploadLimiter, uploadRoutes);
```

---

## Геолокация и карты

### PostGIS для геопространственных запросов

Проект использует **PostGIS расширение** PostgreSQL для эффективной работы с геоданными.

#### 1. Структура геоданных

```prisma
model Event {
  // Обычные координаты для простых операций
  latitude    Float
  longitude   Float
  
  // PostGIS Geography для сложных пространственных запросов
  locationGeo Unsupported("geography(Point, 4326)")?
}

model User {
  lastLatitude  Float?
  lastLongitude Float?
  lastLocationUpdate DateTime?
}
```

**SRID 4326** = WGS84 (стандартная система координат GPS)

#### 2. Создание геоточки при добавлении события

```typescript
// backend/src/services/event.service.ts
async createEvent(data: CreateEventInput) {
  const result = await prisma.$queryRaw<[{ id: string }]>`
    INSERT INTO "Event" (
      id, title, description, category, location,
      latitude, longitude, "locationGeo",
      "dateTime", price, "imageUrl", "isOnline",
      status, "createdById", "createdAt", "updatedAt"
    ) VALUES (
      gen_random_uuid()::text,
      ${data.title},
      ${data.description},
      ${data.category},
      ${data.location},
      ${data.latitude},
      ${data.longitude},
      ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)::geography,
      ${data.dateTime},
      ${data.price ?? 0},
      ${data.imageUrl ?? null},
      ${data.isOnline ?? false},
      'APPROVED'::"EventStatus",
      ${createdById ?? null},
      NOW(),
      NOW()
    )
    RETURNING id
  `;
  
  return await prisma.event.findUnique({ where: { id: result[0].id } });
}
```

**Важно:** Longitude (долгота) идёт первой в `ST_MakePoint(lon, lat)`

#### 3. Поиск событий в радиусе (ST_DWithin)

```typescript
// backend/src/services/event.service.ts
async getNearbyEvents(
  userLat: number,
  userLon: number,
  maxDistance: number = 50000,  // метры
  category?: string,
  page: number = 1,
  limit: number = 20
) {
  const offset = (page - 1) * limit;
  
  const events = await prisma.$queryRaw<any[]>`
    SELECT
      e.*,
      ST_Distance(
        e."locationGeo",
        ST_SetSRID(ST_MakePoint(${userLon}, ${userLat}), 4326)::geography
      ) as distance,
      json_build_object(
        'id', u.id,
        'displayName', u."displayName",
        'photoUrl', u."photoUrl"
      ) as "createdBy",
      COUNT(p.id) as "participantCount"
    FROM "Event" e
    LEFT JOIN "User" u ON e."createdById" = u.id
    LEFT JOIN "Participant" p ON e.id = p."eventId"
    WHERE
      e.status = 'APPROVED'
      AND e."isOnline" = false
      AND ST_DWithin(
        e."locationGeo",
        ST_SetSRID(ST_MakePoint(${userLon}, ${userLat}), 4326)::geography,
        ${maxDistance}
      )
      ${category ? prisma.$queryRaw`AND e.category = ${category}` : prisma.$queryRaw``}
    GROUP BY e.id, u.id
    ORDER BY distance ASC
    LIMIT ${limit}
    OFFSET ${offset}
  `;
  
  return events;
}
```

**ST_DWithin** — высокопроизводительная функция для поиска объектов в радиусе:
- Использует пространственные индексы
- Гораздо быстрее, чем вычисление расстояния для каждой записи
- Работает с метрами при использовании `geography` типа

#### 4. Обновление геолокации пользователя

```typescript
// backend/src/services/user.service.ts
export const updateUserLocation = async (
  userId: string,
  latitude: number,
  longitude: number
): Promise<void> => {
  // Валидация координат
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new Error('Invalid coordinates');
  }
  
  await prisma.user.update({
    where: { id: userId },
    data: {
      lastLatitude: latitude,
      lastLongitude: longitude,
      lastLocationUpdate: new Date(),
    },
  });
};
```

#### 5. Поиск пользователей для матчинга

```typescript
// backend/src/services/user.service.ts
export const getMatchesForUser = async (
  userId: string,
  latitude?: number,
  longitude?: number,
  radiusKm: number = 50,
  limit: number = 20
): Promise<User[]> => {
  const currentUser = await prisma.user.findUnique({ where: { id: userId } });
  
  const userLat = latitude ?? currentUser.lastLatitude;
  const userLon = longitude ?? currentUser.lastLongitude;
  
  if (!userLat || !userLon) {
    return [];
  }
  
  // Вычисляем границы поиска (приближённо)
  const earthRadiusKm = 6371;
  const latChange = (radiusKm / earthRadiusKm) * (180 / Math.PI);
  const lonChange = (radiusKm / (earthRadiusKm * Math.cos((userLat * Math.PI) / 180))) * (180 / Math.PI);
  
  const minLat = userLat - latChange;
  const maxLat = userLat + latChange;
  const minLon = userLon - lonChange;
  const maxLon = userLon + lonChange;
  
  let query: any = {
    where: {
      AND: [
        { id: { not: userId } },
        { isOnboardingCompleted: true },
        { isProfileVisible: true },
        { lastLatitude: { gte: minLat, lte: maxLat } },
        { lastLongitude: { gte: minLon, lte: maxLon } },
      ],
    },
    take: limit,
  };
  
  // Возрастные фильтры
  if (currentUser.minAge || currentUser.maxAge) {
    const ageFilter: any = {};
    if (currentUser.minAge) ageFilter.gte = currentUser.minAge;
    if (currentUser.maxAge) ageFilter.lte = currentUser.maxAge;
    query.where.AND.push({ age: ageFilter });
  }
  
  return await prisma.user.findMany(query);
};
```

### Yandex MapKit (Flutter)

#### 1. Конфигурация

```dart
// lib/config/map_config.dart
class MapConfig {
  static const String apiKey = String.fromEnvironment('YANDEX_MAPKIT_API_KEY');
  
  static const Point defaultLocation = Point(
    latitude: 55.751244,   // Москва
    longitude: 37.618423,
  );
}
```

#### 2. Инициализация карты

```dart
// lib/presentation/events/map_view.dart
class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late YandexMapController _mapController;
  
  @override
  Widget build(BuildContext context) {
    return YandexMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      mapObjects: _buildPlacemarks(events),
      onCameraPositionChanged: (position, reason, finished) {
        if (finished) {
          _loadEventsInVisibleArea(position);
        }
      },
    );
  }
  
  List<MapObject> _buildPlacemarks(List<EventModel> events) {
    return events.map((event) {
      return PlacemarkMapObject(
        mapId: MapObjectId(event.id),
        point: Point(latitude: event.latitude, longitude: event.longitude),
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('assets/icons/event_pin.png'),
            scale: 0.5,
          ),
        ),
        onTap: (placemark, point) => _showEventDetails(event),
      );
    }).toList();
  }
}
```

#### 3. Получение текущей локации

```dart
// lib/data/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    // Проверка разрешений
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    }
    
    // Получение координат
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
  
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,  // Обновление каждые 100 метров
      ),
    );
  }
}
```

#### 4. Geocoding (адрес → координаты)

```dart
// lib/data/services/geocoding_service.dart
import 'package:yandex_geocoder/yandex_geocoder.dart';

class GeocodingService {
  final YandexGeocoder _geocoder = YandexGeocoder(apiKey: MapConfig.apiKey);
  
  Future<GeocodeResponse?> getCoordinatesFromAddress(String address) async {
    try {
      final response = await _geocoder.getGeocode(GeocodeRequest(
        geocode: address,
        lang: Lang.ru,
      ));
      return response;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }
  
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final response = await _geocoder.getGeocode(GeocodeRequest(
        geocode: PointGeocode(latitude: lat, longitude: lon),
        lang: Lang.ru,
      ));
      return response.firstAddress?.formatted;
    } catch (e) {
      print('Reverse geocoding error: $e');
      return null;
    }
  }
}
```

---

## Безопасность

### 1. Безопасность API

#### Rate Limiting
```typescript
// Защита от brute-force атак
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Слишком много попыток. Попробуйте позже.',
});
```

#### Helmet.js
```typescript
// Установка безопасных HTTP заголовков
app.use(helmet());
```

#### CORS
```typescript
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true,
}));
```

### 2. Валидация данных

#### Zod Schema Validation
```typescript
import { z } from 'zod';

const createEventSchema = z.object({
  title: z.string().min(3).max(100),
  description: z.string().min(10).max(5000),
  category: z.string(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  dateTime: z.string().datetime(),
  price: z.number().min(0).optional(),
});
```

### 3. SQL Injection защита

Prisma автоматически защищает от SQL injection, но для raw queries используются параметризованные запросы:

```typescript
// ✅ Правильно (параметризованный)
await prisma.$queryRaw`
  SELECT * FROM "User" WHERE email = ${userEmail}
`;

// ❌ Неправильно (уязвимо)
await prisma.$queryRawUnsafe(`
  SELECT * FROM "User" WHERE email = '${userEmail}'
`);
```

### 4. Path Traversal защита

```typescript
function sanitizeFilename(filename: string): string {
  return filename
    .replaceAll('..', '')
    .replaceAll(/[/\\]/g, '')
    .replaceAll(/[^\w\s.-]/g, '')
    .trim();
}

// Проверка реального пути
const realUploadDir = fs.realpathSync(baseUploadDir);
const realTargetDir = fs.realpathSync(uploadDir);

if (!realTargetDir.startsWith(realUploadDir)) {
  throw new Error('Path traversal attempt detected');
}
```

### 5. XSS защита

```dart
// Flutter автоматически экранирует текст в Text()
Text(userInput);  // Безопасно

// Для HTML контента используйте flutter_html
Html(data: sanitizeHtml(userHtml));
```

### 6. Хранение секретов

```bash
# .env (НЕ коммитить!)
DATABASE_URL="postgresql://..."
SUPABASE_JWT_SECRET="..."
YANDEX_MAPS_API_KEY="..."
```

```dart
// Использование --dart-define
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

### 7. Безопасность паролей

```typescript
import bcrypt from 'bcrypt';

// Хеширование
const hashedPassword = await bcrypt.hash(password, 10);

// Проверка
const isValid = await bcrypt.compare(password, hashedPassword);
```

### 8. HTTPS Only (Production)

```typescript
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.header('x-forwarded-proto') !== 'https') {
      return res.redirect(`https://${req.header('host')}${req.url}`);
    }
    next();
  });
}
```

---

## Рекомендации по улучшению

### 1. База данных

**✅ Текущее состояние:**
- Prisma ORM с PostgreSQL
- PostGIS для геопространственных запросов
- Индексы на ключевых полях

**🔧 Рекомендации:**

1. **Добавить составные индексы:**
```prisma
model Event {
  @@index([status, dateTime])
  @@index([category, status])
  @@index([createdById, status])
}
```

2. **Добавить GIST индекс для locationGeo:**
```sql
CREATE INDEX event_location_gist_idx ON "Event" USING GIST ("locationGeo");
```

3. **Партиционирование таблицы Event по дате:**
```sql
-- Для архивации старых событий
CREATE TABLE event_2024 PARTITION OF "Event"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

4. **Добавить soft delete:**
```prisma
model Event {
  deletedAt DateTime?
  
  @@index([deletedAt])
}
```

### 2. Кеширование

**Рекомендуется добавить Redis:**

```typescript
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// Кеширование списка событий
async function getCachedEvents(cacheKey: string) {
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);
  
  const events = await eventService.getAllEvents();
  await redis.setex(cacheKey, 300, JSON.stringify(events)); // 5 минут
  return events;
}
```

**Что кешировать:**
- Список событий (на 5 минут)
- Профили пользователей (на 10 минут)
- Результаты геокодинга (на 1 день)
- Подсчёт участников события (на 1 минуту)

### 3. Оптимизация изображений

**Рекомендуется:**

1. **Генерация thumbnails:**
```typescript
// При загрузке создавать 3 версии
await Promise.all([
  sharp(input).resize(1200, 1200).toFile('large.jpg'),
  sharp(input).resize(600, 600).toFile('medium.jpg'),
  sharp(input).resize(200, 200).toFile('thumb.jpg'),
]);
```

2. **WebP формат:**
```typescript
await sharp(input)
  .webp({ quality: 80 })
  .toFile('image.webp');
```

3. **Lazy loading на клиенте:**
```dart
CachedNetworkImage(
  imageUrl: event.imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
);
```

### 4. Масштабирование

**Рекомендации для production:**

1. **Разделение сервисов:**
```
┌──────────────┐
│   API Server │ ← Основная логика
└──────────────┘
┌──────────────┐
│ Upload Server│ ← Загрузка файлов
└──────────────┘
┌──────────────┐
│  WebSocket   │ ← Реалтайм (матчи, чат)
└──────────────┘
```

2. **Горизонтальное масштабирование:**
```nginx
upstream api_servers {
  server api1.example.com;
  server api2.example.com;
  server api3.example.com;
}
```

3. **CDN для статики:**
```typescript
// Использовать CloudFront, Cloudflare или Akamai
const imageUrl = `${CDN_URL}/uploads/events/${filename}`;
```

### 5. Мониторинг и аналитика

**Рекомендуется добавить:**

1. **Sentry для отслеживания ошибок:**
```typescript
import * as Sentry from '@sentry/node';

Sentry.init({ dsn: process.env.SENTRY_DSN });

app.use(Sentry.Handlers.errorHandler());
```

2. **Prometheus метрики:**
```typescript
import promClient from 'prom-client';

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
});
```

3. **Health checks:**
```typescript
app.get('/health', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});
```

### 6. Тестирование

**Рекомендуется добавить:**

1. **Unit тесты (Jest):**
```typescript
describe('EventService', () => {
  it('should create event with valid data', async () => {
    const event = await eventService.createEvent(mockEventData);
    expect(event.id).toBeDefined();
    expect(event.status).toBe('PENDING');
  });
});
```

2. **Integration тесты:**
```typescript
describe('POST /api/events', () => {
  it('should return 401 without auth token', async () => {
    const res = await request(app)
      .post('/api/events')
      .send(mockEventData);
    expect(res.status).toBe(401);
  });
});
```

3. **E2E тесты (Flutter):**
```dart
testWidgets('should create event successfully', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  
  expect(find.text('Create Event'), findsOneWidget);
});
```

### 7. Безопасность (дополнительно)

1. **Двухфакторная аутентификация:**
```typescript
import speakeasy from 'speakeasy';

// Генерация секрета
const secret = speakeasy.generateSecret();

// Верификация кода
const verified = speakeasy.totp.verify({
  secret: user.totpSecret,
  encoding: 'base32',
  token: userCode,
});
```

2. **Audit log:**
```prisma
model AuditLog {
  id        String   @id @default(uuid())
  userId    String
  action    String   // CREATE_EVENT, DELETE_USER, etc.
  entityId  String
  entityType String
  metadata  Json?
  createdAt DateTime @default(now())
  
  @@index([userId])
  @@index([action])
  @@index([createdAt])
}
```

3. **IP Whitelist для админки:**
```typescript
const adminWhitelist = ['192.168.1.1', '10.0.0.1'];

app.use('/admin', (req, res, next) => {
  if (!adminWhitelist.includes(req.ip)) {
    return res.status(403).json({ message: 'Access denied' });
  }
  next();
});
```

### 8. Производительность Flutter

1. **Виртуализация списков:**
```dart
ListView.builder(
  itemCount: events.length,
  itemBuilder: (context, index) => EventCard(events[index]),
);
```

2. **Мемоизация виджетов:**
```dart
class EventCard extends StatelessWidget {
  const EventCar