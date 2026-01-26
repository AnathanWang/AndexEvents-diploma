# Интеграция Supabase и завершение хранения изображений

## СОДЕРЖАНИЕ

1. [Продолжение хранения изображений](#продолжение-хранения-изображений)
2. [Интеграция Supabase](#интеграция-supabase)
3. [Локальное хранилище на сервере](#локальное-хранилище-на-сервере)
4. [Сравнение подходов](#сравнение-подходов)

---

## ПРОДОЛЖЕНИЕ ХРАНЕНИЯ ИЗОБРАЖЕНИЙ

### Использование в UI (Flutter)

```dart
// Обновление профиля с новым URL
    final userService = UserService();
    await userService.updateProfile(
      photoUrl: imageUrl,
    );

    emit(ProfileUploaded(imageUrl: imageUrl));
  } catch (e) {
    emit(ProfileUploadError(error: e.toString()));
  }
}
```

### Отображение изображений

**Виджет для отображения изображений из Supabase:**

```dart
// lib/presentation/widgets/common/cached_image_widget.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(0),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => 
          placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) => 
          errorWidget ?? _buildErrorWidget(),
        fadeInDuration: Duration(milliseconds: 300),
        fadeOutDuration: Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[500],
        size: 48,
      ),
    );
  }
}
```

**Пример использования:**

```dart
// Аватар пользователя
CachedImageWidget(
  imageUrl: user.photoUrl,
  width: 100,
  height: 100,
  borderRadius: BorderRadius.circular(50),
  placeholder: CircleAvatar(
    radius: 50,
    child: Icon(Icons.person, size: 50),
  ),
)

// Фото события
CachedImageWidget(
  imageUrl: event.imageUrl,
  width: double.infinity,
  height: 200,
  borderRadius: BorderRadius.circular(16),
)
```

### Преимущества Supabase Storage

✅ **Масштабируемость** - автоматическое управление хранилищем
✅ **CDN** - быстрая доставка контента по всему миру
✅ **Резервное копирование** - автоматические бэкапы
✅ **Трансформация изображений** - изменение размера на лету
✅ **Безопасность** - Row Level Security (RLS)
✅ **Интеграция** - бесшовная работа с Supabase Auth

### Недостатки

⚠️ **Зависимость от интернета** - нужен онлайн для загрузки
⚠️ **Стоимость** - платно при превышении лимитов
⚠️ **Задержка** - время загрузки зависит от скорости интернета

---

## ИНТЕГРАЦИЯ SUPABASE

### Что такое Supabase?

**Supabase** — это open-source альтернатива Firebase, предоставляющая:
- PostgreSQL база данных
- Authentication (OAuth, Email/Password, Magic Links)
- Storage (хранение файлов)
- Real-time subscriptions
- Edge Functions

### Архитектура интеграции

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter App                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │           Supabase Flutter Client                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │  │
│  │  │    Auth      │  │   Storage    │  │Database │ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └────┬────┘ │  │
│  └─────────┼─────────────────┼───────────────┼──────┘  │
└────────────┼─────────────────┼───────────────┼─────────┘
             │                 │               │
             │ JWT Token       │ Files         │ (optional)
             │                 │               │
             ▼                 ▼               ▼
┌────────────────────────────────────────────────────────┐
│                  Supabase Cloud                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Auth API    │  │   Storage    │  │  PostgreSQL  │ │
│  │  (GoTrue)    │  │   Bucket     │  │   Database   │ │
│  └──────┬───────┘  └──────────────┘  └──────────────┘ │
└─────────┼──────────────────────────────────────────────┘
          │
          ▼
┌──────────────────┐
│   Backend API    │ ← Верифицирует JWT токен
│  (Node.js)       │
└──────────────────┘
```

### Настройка проекта в Supabase

#### 1. Создание проекта

1. Зайдите на https://supabase.com
2. Создайте новый проект
3. Запишите:
   - **Project URL**: `https://[project-id].supabase.co`
   - **Anon Key**: публичный ключ для клиента
   - **Service Role Key**: секретный ключ для backend (НИКОГДА не используйте в клиенте!)
   - **JWT Secret**: для верификации токенов на backend

#### 2. Настройка Authentication

**Включение Email/Password:**

```sql
-- В Supabase Dashboard → Authentication → Providers
-- Включите Email provider
-- Настройки:
-- ✅ Enable email confirmations: false (для разработки)
-- ✅ Enable email confirmations: true (для production)
```

**Включение Google OAuth:**

1. Создайте OAuth credentials в Google Cloud Console
2. Добавьте в Supabase Dashboard → Authentication → Providers → Google:
   - Client ID: `your-client-id.apps.googleusercontent.com`
   - Client Secret: `your-client-secret`

**Включение Apple Sign In:**

1. Настройте в Apple Developer Console
2. Добавьте в Supabase → Providers → Apple:
   - Services ID
   - Team ID
   - Key ID
   - Private Key

#### 3. Настройка Storage Buckets

**Создание бакетов через SQL:**

```sql
-- Bucket для аватаров
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Bucket для событий
INSERT INTO storage.buckets (id, name, public)
VALUES ('events', 'events', true);
```

**Настройка Storage Policies:**

```sql
-- 1. Публичный доступ на чтение
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id IN ('avatars', 'events'));

-- 2. Загрузка только для авторизованных
CREATE POLICY "Authenticated can upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id IN ('avatars', 'events')
  AND auth.role() = 'authenticated'
);

-- 3. Обновление только своих файлов
CREATE POLICY "Users can update own files"
ON storage.objects FOR UPDATE
USING (
  bucket_id IN ('avatars', 'events')
  AND auth.uid()::text = owner
);

-- 4. Удаление только своих файлов
CREATE POLICY "Users can delete own files"
ON storage.objects FOR DELETE
USING (
  bucket_id IN ('avatars', 'events')
  AND auth.uid()::text = owner
);
```

### Инициализация Supabase в Flutter

**1. Установка зависимостей:**

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.6.0
  google_sign_in: ^6.2.2  # для Google OAuth
```

**2. Инициализация в main.dart:**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,  // Более безопасный flow
    ),
    storageOptions: StorageClientOptions(
      retryAttempts: 3,  // Повторные попытки при ошибках
    ),
  );

  print('✅ Supabase инициализирован');

  runApp(const MyApp());
}
```

**3. Конфигурация:**

```dart
// lib/core/config/app_config.dart
class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://[project-id].supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
  
  // ВАЖНО: НЕ включайте Service Role Key в клиентский код!
}
```

### Authentication в Flutter

**Сервис аутентификации:**

```dart
// lib/data/services/auth_service.dart
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    _googleSignIn = GoogleSignIn(
      clientId: '672417054710-2gm36ur4k2nj5a7ed2re974mmq4qmt34.apps.googleusercontent.com',
      scopes: ['email', 'profile'],
    );
  }

  // Получить текущего пользователя
  User? get currentUser => _supabase.auth.currentUser;

  // Stream для отслеживания изменений
  Stream<AuthState> get authStateChanges => 
    _supabase.auth.onAuthStateChange;

  /// Регистрация через Email
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      // Если требуется подтверждение email
      if (response.user != null && response.session == null) {
        throw Exception(
          'Для завершения регистрации подтвердите email. '
          'Проверьте почту.'
        );
      }

      // Создать пользователя в backend
      if (response.user != null) {
        await _createUserInBackend(
          supabaseUid: response.user!.id,
          email: email,
          displayName: displayName,
        );
      }

      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Вход через Email
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Вход через Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // 1. Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In отменён');
      }

      // 2. Получение токенов
      final GoogleSignInAuthentication googleAuth = 
        await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Не удалось получить токены от Google');
      }

      // 3. Вход в Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // 4. Создание пользователя в backend
      if (response.user != null) {
        await _createUserInBackend(
          supabaseUid: response.user!.id,
          email: response.user!.email!,
          displayName: response.user!.userMetadata?['full_name'] ?? 
                       googleUser.displayName ?? 
                       'User',
          photoUrl: response.user!.userMetadata?['avatar_url'] ?? 
                    googleUser.photoUrl,
        );
      }

      // 5. Получение статуса онбординга
      bool isOnboardingCompleted = false;
      try {
        final profileData = await getCurrentUserProfile();
        isOnboardingCompleted = 
          profileData['isOnboardingCompleted'] as bool? ?? false;
      } catch (e) {
        print('Не удалось получить профиль: $e');
      }

      return {
        'userCredential': response,
        'isOnboardingCompleted': isOnboardingCompleted,
      };
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Выход
  Future<void> signOut() async {
    await Future.wait([
      _supabase.auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Получить JWT токен
  Future<String?> getIdToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Обновить токен
  Future<void> refreshSession() async {
    await _supabase.auth.refreshSession();
  }

  /// Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Получить профиль из backend
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Не авторизован');
      }

      final token = session.accessToken;
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Ошибка загрузки профиля');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  /// Создать пользователя в backend
  Future<void> _createUserInBackend({
    required String supabaseUid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'supabaseUid': supabaseUid,
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode != 201 && response.statusCode != 409) {
        throw Exception('Ошибка создания в БД (${response.statusCode})');
      }
    } catch (e) {
      print('Ошибка создания в backend: $e');
    }
  }

  /// Обработка ошибок
  Exception _handleAuthException(dynamic e) {
    if (e is AuthException) {
      final message = e.message.toLowerCase();
      
      if (message.contains('invalid') && message.contains('email')) {
        return Exception('Некорректный email');
      }
      if (message.contains('user already registered')) {
        return Exception('Email уже зарегистрирован');
      }
      if (message.contains('invalid login credentials')) {
        return Exception('Неверный email или пароль');
      }
      if (message.contains('email not confirmed')) {
        return Exception('Email не подтверждён');
      }
      
      return Exception('Ошибка: ${e.message}');
    }
    
    return Exception('Ошибка: $e');
  }
}
```

### Backend: Верификация JWT токенов

**Middleware для проверки токенов:**

```typescript
// backend/src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../utils/prisma.js';

export interface AuthRequest extends Request {
  user?: {
    uid: string;          // Supabase UID
    userId?: string;      // ID из нашей БД
    email?: string;
  };
}

export const authMiddleware = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // 1. Извлекаем токен из заголовка
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        message: 'No token provided',
      });
      return;
    }

    const token = authHeader.split('Bearer ')[1];

    // 2. Верифицируем JWT токен
    const jwtSecret = process.env.SUPABASE_JWT_SECRET;
    if (!jwtSecret) {
      throw new Error('SUPABASE_JWT_SECRET not configured');
    }

    const decoded = jwt.verify(token, jwtSecret) as jwt.JwtPayload;
    
    if (!decoded.sub) {
      throw new Error('Token missing sub claim');
    }

    // 3. Находим пользователя в нашей БД
    const user = await prisma.user.findUnique({
      where: { supabaseUid: decoded.sub }
    });

    // 4. Сохраняем данные в request
    req.user = {
      uid: decoded.sub,
      userId: user?.id,
      email: decoded.email,
    };

    next();
  } catch (error) {
    console.error('Auth error:', error);
    res.status(401).json({
      success: false,
      message: 'Invalid token',
    });
  }
};
```

**Получение JWT Secret из Supabase:**

1. Перейдите в Supabase Dashboard
2. Settings → API
3. Скопируйте **JWT Secret**
4. Добавьте в `.env`:

```env
# backend/.env
SUPABASE_JWT_SECRET=your-jwt-secret-here
```

### Переменные окружения

**Backend (.env):**

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/andexevents"

# Supabase
SUPABASE_URL="https://[project-id].supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
SUPABASE_JWT_SECRET="your-jwt-secret"
# ВАЖНО: Не используйте Service Role Key в обычном коде!

# Server
PORT=3000
NODE_ENV=development
```

**Flutter (через --dart-define):**

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api \
  --dart-define=SUPABASE_URL=https://[project-id].supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## ЛОКАЛЬНОЕ ХРАНИЛИЩЕ НА СЕРВЕРЕ

### Архитектура

```
┌─────────────┐                    ┌──────────────────┐
│   Flutter   │                    │   Backend API    │
│     App     │─────Upload────────>│   (Node.js)      │
│             │                    │                  │
│             │<────URL────────────│  ┌─────────────┐ │
│             │                    │  │public/      │ │
│             │                    │  │  uploads/   │ │
│             │                    │  │    avatars/ │ │
│             │                    │  │    events/  │ │
└─────────────┘                    │  └─────────────┘ │
                                   └──────────────────┘
```

### Структура директорий

```
backend/public/uploads/
├── avatars/
│   ├── user-550e8400.../
│   │   ├── 1702390123456-a1b2c3.jpg
│   │   └── 1702390124567-d4e5f6.jpg
│   └── user-650e8400.../
│       └── 1702390125678-g7h8i9.jpg
│
└── events/
    ├── user-550e8400.../
    │   ├── 1702390126789-j0k1l2.jpg
    │   └── 1702390127890-m3n4o5.jpg
    └── user-650e8400.../
        └── 1702390128901-p6q7r8.jpg
```

### Backend: Multer для загрузки

**Routes:**

```typescript
// backend/src/routes/upload.routes.ts
import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import uploadController from '../controllers/upload.controller.js';
import { authMiddleware } from '../middleware/auth.middleware.js';

const router = Router();

// Настройка Multer storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const bucket = (req.query.bucket as string) || 'events';
    const userId = (req as any).user?.userId;
    
    if (!userId) {
      return cb(new Error('User ID required'), '');
    }

    // Путь: public/uploads/{bucket}/{userId}/
    const uploadDir = path.join(
      process.cwd(), 
      `public/uploads/${bucket}/${userId}`
    );
    
    // Создаём директорию если нет
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  
  filename: (req, file, cb) => {
    // Имя: timestamp-random.ext
    const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(4).toString('hex');
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    // Валидация типа файла
    const mimeType = file.mimetype.toLowerCase();
    const isValidImage = mimeType.startsWith('image/');
    
    const ext = path.extname(file.originalname).toLowerCase();
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    
    if (isValidImage && validExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});

// POST /api/upload?bucket=avatars
router.post(
  '/', 
  authMiddleware, 
  upload.single('file'), 
  uploadController.uploadFile
);

export default router;
```

**Controller:**

```typescript
// backend/src/controllers/upload.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware.js';
import logger from '../utils/logger.js';
import prisma from '../utils/prisma.js';

class UploadController {
  async uploadFile(req: AuthRequest, res: Response) {
    const bucket = (req.query.bucket as string) || 'events';
    const userId = req.user?.userId;
    
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Unauthorized',
      });
    }

    try {
      const file = (req as any).file;
      if (!file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
        });
      }

      const fileName = file.filename;
      const fileSize = file.size;
      
      // Публичный URL: /uploads/{bucket}/{userId}/{filename}
      const protocol = req.protocol;
      const host = req.get('host');
      const publicUrl = `${protocol}://${host}/uploads/${bucket}/${userId}/${fileName}`;

      logger.info('File uploaded:', {
        fileName,
        fileSize: `${(fileSize / 1024 / 1024).toFixed(2)}MB`,
        bucket,
        userId,
        url: publicUrl,
      });

      // Если аватар - обновляем в БД
      if (bucket === 'avatars') {
        await prisma.user.update({
          where: { id: userId },
          data: { photoUrl: publicUrl }
        });
      }

      return res.json({
        success: true,
        fileUrl: publicUrl,
        file: {
          name: fileName,
          size: fileSize,
          bucket: bucket,
        }
      });

    } catch (error: any) {
      logger.error('Upload error:', error);
      return res.status(500).json({
        success: false,
        message: 'Upload failed',
      });
    }
  }
}

export default new UploadController();
```

**Middleware защиты файлов:**

```typescript
// backend/src/middleware/file-access.middleware.ts
import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth.middleware.js';
import logger from '../utils/logger.js';

export const fileAccessMiddleware = (
  req: AuthRequest, 
  res: Response, 
  next: NextFunction
) => {
  // GET - разрешаем всем (публичные файлы)
  if (req.method === 'GET') {
    // Проверка на Path Traversal
    if (req.path.includes('..') || req.path.includes('//')) {
      return res.status(400).json({
        success: false,
        message: 'Invalid path'
      });
    }
    return next();
  }

  // POST/PUT/DELETE - требуют авторизации
  const authenticatedUserId = req.user?.userId;
  if (!authenticatedUserId) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized'
    });
  }

  // Проверяем, что пользователь обращается к своим файлам
  const parts = req.path.split('/').filter(Boolean);
  const [bucket, fileUserId] = parts;
  
  if (fileUserId !== authenticatedUserId) {
    logger.error('Unauthorized file access attempt:', {
      authenticatedUserId,
      attemptedFileUserId: fileUserId,
    });
    
    return res.status(403).json({
      success: false,
      message: 'Access denied'
    });
  }

  next();
};
```

### Настройка сервера

```typescript
// backend/src/index.ts
import express from 'express';
import path from 'node:path';
import uploadRoutes from './routes/upload.routes.js';
import { fileAccessMiddleware } from './middleware/file-access.middleware.js';

const app = express();

// Middleware для проверки доступа к файлам
app.use('/uploads', fileAccessMiddleware);

// Статические файлы
app.use('/uploads', express.static(
  path.join(process.cwd(), 'public/uploads')
));

// Upload routes
app.use('/api/upload', uploadRoutes);

app.listen(3000);
```

### Flutter: Загрузка на backend

```dart
// lib/data/services/backend_upload_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/image_utils.dart';
import '../services/auth_service.dart';

class BackendUploadService {
  final Dio _dio;
  final AuthService _authService;

  BackendUploadService({
    required AuthService authService,
  }) : _authService = authService,
       _dio = Dio(BaseOptions(
         baseUrl: AppConfig.baseUrl,
         connectTimeout: Duration(seconds: 30),
         receiveTimeout: Duration(seconds: 30),
       ));

  /// Загрузить аватар на backend
  Future<String> uploadAvatar(String filePath) async {
    try {
      // 1. Сжатие
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(
        originalFile,
        quality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      // 2. Получение токена
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // 3. Формирование multipart
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'avatar.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      // 4. Загрузка
      final response = await _dio.post(
        '/upload?bucket=avatars',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
        onSendProgress: (sent, total) {
          final progress = sent / total;
          print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200) {
        final fileUrl = response.data['fileUrl'] as String;
        return fileUrl;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }
  }

  /// Загрузить фото события
  Future<String> uploadEventPhoto(String filePath) async {
    try {
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(
        originalFile,
        quality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'event.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post(
        '/upload?bucket=events',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['fileUrl'] as String;
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      rethrow;
    }
  }
}
```

---

## СРАВНЕНИЕ ПОДХОДОВ

### Таблица сравнения

| Критерий | Supabase Storage | Backend (Multer) | Local Device |
|----------|------------------|------------------|--------------|
| **Сложность настройки** | 🟢 Низкая | 🟡 Средняя | 🟢 Низкая |
| **Масштабируемость** | 🟢 Отличная | 🟡 Средняя | 🔴 Плохая |
| **Стоимость** | 🟡 Платно после лимита | 🟢 Только сервер | 🟢 Бесплатно |
| **Скорость загрузки** | 🟢 Быстро (CDN) | 🟡 Зависит от сервера | 🟢 Мгновенно |
| **Резервное копирование** | 🟢 Автоматическое | 🔴 Нужно настраивать | 🔴 Нет |
| **Offline доступ** | 🔴 Нет | 🔴 Нет | 🟢 Да |
| **Синхронизация устройств** | 🟢 Да | 🟢 Да | 🔴 Нет |
| **Трансформация изображений** | 🟢 Да (на лету) | 🟡 Нужна настройка | 🔴 Нет |
| **Безопасность** | 🟢 RLS policies | 🟡 Свои middleware | 🟡 Локальное хранилище |
| **Управление** | 🟢 Простое (Dashboard) | 🟡 SSH + файловая система | 🟢 Через приложение |

### Рекомендации по выбору

**Используйте Supabase Storage если:**
- ✅ Нужна высокая масштабируемость
- ✅ Важна скорость загрузки по всему миру (CDN)
- ✅ Нужны автоматические бэкапы
- ✅ Планируете трансформацию изображений
- ✅ Хотите минимум настройки

**Используйте Backend (Multer) если:**
- ✅ Хотите полный контроль над файлами
- ✅ Нужно хранить файлы на своём сервере
- ✅ Хотите избежать зависимости от внешних сервисов
- ✅ Есть специфические требования к обработке файлов

**Используйте Local Storage если:**
- ✅ Нужна работа offline
- ✅ Данные не критичны (можно потерять при удалении приложения)
- ✅ Прототип или MVP
- ⚠️ Не рекомендуется для production

### Гибридный подход (Рекомендуется)

**Наилучшая практика:**

1. **Основное хранилище:** Supabase Storage
2. **Локальный кеш:** Для просмотренных изображений
3. **Fallback:** Backend storage для специальных случаев

```dart
// lib/data/services/unified_upload_service.dart
class UnifiedUploadService {
  final SupabaseUploadService _supabase;
  final BackendUploadService _backend;
  final LocalStorageService _local;

  UnifiedUploadService({
    required SupabaseUploadService supabase,
    required BackendUploadService backend,
    required LocalStorageService local,
  }) : _supabase = supabase,
       _backend = backend,
       _local = local;

  Future<String> uploadAvatar(String filePath) async {
    try {
      // Пробуем Supabase (основной)
      return await _supabase.uploadProfilePhoto(filePath);
    } catch (e) {
      print('Supabase failed, trying backend: $e');
      
      try {
        // Fallback на backend
        return await _backend.uploadAvatar(filePath);
      } catch (e2) {
        print('Backend failed, using local: $e2');
        
        // Последний вариант - локально
        return await _local.uploadProfilePhoto(filePath);
      }
    }
  }
}
```

---

## ЗАКЛЮЧЕНИЕ

### Итоговые рекомендации

**Для production-ready проекта:**

1. **Основное хранилище:** Supabase Storage
   - Надёжно, быстро, масштабируемо
   - CDN для быстрой доставки
   - Автоматические бэкапы

2. **Аутентификация:** Supabase Auth
   - Проверенное решение
   - Множество OAuth провайдеров
   - JWT токены для backend

3. **База данных:** PostgreSQL (собственная или Supabase)
   - Полный контроль над схемой
   - PostGIS для геопоиска
   - Prisma ORM для type-safety

4. **Кеширование:** Redis
   - Для API responses
   - Для часто запрашиваемых данных

5. **Мониторинг:** Sentry + Prometheus
   - Отслеживание ошибок
   - Метрики производительности

### Безопасность

**Чек-лист:**
- ✅ JWT токены для аутентификации
- ✅ HTTPS везде
- ✅ Rate limiting
- ✅ Валидация файлов (MIME type + magic bytes)
- ✅ Защита от Path Traversal
- ✅ RLS policies в Supabase
- ✅ Middleware для проверки доступа
- ✅ Не храните секреты в коде

### Производительность

**Оптимизации:**
- ✅ Сжатие изображений перед загрузкой
- ✅ WebP формат где возможно
- ✅ Генерация thumbnails
- ✅ Кеширование с CachedNetworkImage
- ✅ Lazy loading списков
- ✅ Индексы в БД

---

**Дата создания:** 2024-12-13
**Версия:** 1.0
**Автор:** Документация проекта Andex Events