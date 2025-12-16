# Локальное хранилище изображений

## Описание

Приложение переведено на использование локального хранилища вместо Supabase Storage. Логика работы остается такой же, как в Supabase:
- Бакеты: `avatars` (профили), `events` (фото событий)
- Сжатие изображений перед сохранением
- Проверка размера файла
- Отслеживание прогресса загрузки

## Архитектура

```
📱 Приложение
├── Event/User BLoC
│   ├── EventService
│   │   └── LocalStorageService.uploadEventPhoto()
│   ├── UserService
│   │   └── LocalStorageService.uploadProfilePhoto()
│
├── LocalStorageService (Singleton)
│   ├── /Documents/storage/avatars/
│   │   └── {timestamp}.jpg
│   └── /Documents/storage/events/
│       └── {timestamp}.jpg
│
└── LocalImageDisplay (Widget)
    ├── Проверяет тип URL (локальный/сетевой)
    ├── Для локальных: Image.file()
    └── Для сетевых: CachedNetworkImage()
```

## Используемые компоненты

### 1. LocalStorageService (`lib/data/services/local_storage_service.dart`)
- Singleton сервис для управления локальным хранилищем
- Методы:
  - `initialize()` - инициализация при старте приложения
  - `uploadEventPhoto(String filePath)` - загрузка фото события
  - `uploadProfilePhoto(String filePath)` - загрузка фото профиля
  - `deleteFile(String filePath)` - удаление файла
  - `listFiles(String bucketName)` - получить список файлов
  - `clearBucket(String bucketName)` - очистить бакет
  - `getStorageSize(String bucketName)` - размер бакета

### 2. LocalImageDisplay (`lib/presentation/widgets/common/local_image_display.dart`)
- Виджет для отображения изображений
- Автоматически определяет тип URL:
  - Если начинается с `/` → локальный файл → `Image.file()`
  - Иначе → сетевой URL → `CachedNetworkImage()`
- Свойства:
  - `imageUrl` - путь или URL изображения
  - `fit` - режим масштабирования (по умолчанию `BoxFit.cover`)
  - `width`, `height` - размеры
  - `borderRadius` - скругление углов
  - `backgroundColor` - цвет при загрузке

### 3. LocalImageProvider
- Custom ImageProvider для локальных файлов
- Используется в `Image(image: LocalImageProvider(path))`

## Примеры использования

### Загрузка фото события
```dart
final eventService = EventService();
final photoFile = File(pickedFile.path);

try {
  final localPath = await eventService.uploadEventPhoto(photoFile);
  // localPath: /Users/.../Documents/storage/events/1702390123456.jpg
  
  // Обновить событие с новым путем
  event = event.copyWith(imageUrl: localPath);
} catch (e) {
  print('Ошибка загрузки: $e');
}
```

### Отображение фото
```dart
// Вариант 1: Использование LocalImageDisplay (рекомендуется)
LocalImageDisplay(
  imageUrl: eventModel.imageUrl,
  width: 300,
  height: 200,
  borderRadius: BorderRadius.circular(12),
)

// Вариант 2: Прямое использование Image.file()
Image.file(
  File(eventModel.imageUrl),
  fit: BoxFit.cover,
  errorBuilder: (_, __, ___) => Icon(Icons.broken_image),
)

// Вариант 3: С использованием Provider
Image(
  image: LocalImageProvider(eventModel.imageUrl),
  fit: BoxFit.cover,
)
```

## Миграция из Supabase

Если нужно перенести существующие фото с Supabase:

```dart
import 'package:http/http.dart' as http;

Future<String> migrateSupabaseImage(String supabaseUrl) async {
  // Загрузить из Supabase
  final response = await http.get(Uri.parse(supabaseUrl));
  final bytes = response.bodyBytes;
  
  // Сохранить локально
  final fileName = DateTime.now().millisecondsSinceEpoch.toString();
  final bucket = _getBucket('events');
  final outputPath = '${bucket.path}/$fileName.jpg';
  
  await File(outputPath).writeAsBytes(bytes);
  return outputPath;
}
```

## Особенности

### ✅ Преимущества
- Нет зависимостей от интернета для отображения
- Быстрое открытие фото (локальный доступ)
- Нет проблем с кешированием
- Контроль над размером файлов
- Простая структура (напоминает Supabase бакеты)

### ⚠️ Недостатки
- Фото хранятся только на устройстве (нет облачного бэкапа)
- При удалении приложения - потеря данных
- Нет синхронизации между устройствами
- Требует значительно больше памяти на устройстве

## Логирование

LocalStorageService выводит логи при:
- 🔵 `[LocalStorage]` - начало операции
- 🟢 `[LocalStorage]` - успешное завершение
- 🔴 `[LocalStorage]` - ошибка

Пример:
```
🔵 [LocalStorage] Начинаем загрузку фото события...
🔵 [LocalStorage] Копируем файл: /Users/.../Documents/storage/events/1702390123456.jpg
🟢 [LocalStorage] Фото события сохранено: /Users/.../Documents/storage/events/1702390123456.jpg
```

## Структура каталогов

```
📱 App Documents Directory
└── storage/
    ├── avatars/
    │   ├── 1702390123456.jpg
    │   ├── 1702390124567.jpg
    │   └── 1702390125678.jpg
    └── events/
        ├── 1702390126789.jpg
        ├── 1702390127890.jpg
        └── 1702390128901.jpg
```

## Инициализация

В `main.dart` происходит инициализация:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... другая инициализация ...
  
  // Инициализировать локальное хранилище
  await LocalStorageService().initialize();
  
  // ... запуск приложения ...
}
```

## Размеры файлов

- Фото события: макс. 10MB (после сжатия обычно 200-800KB)
- Фото профиля: макс. 5MB (после сжатия обычно 100-300KB)
- Сжатие: 70% качество, минимум 512x512 px

## Модель данных

События и профили по-прежнему используют поле `imageUrl`:

```dart
class EventModel {
  final String? imageUrl; // Теперь это локальный путь
  // ...
}

class UserModel {
  final String? avatar; // Теперь это локальный путь
  // ...
}
```

## FAQ

**Q: Можно ли использовать Supabase URL одновременно?**
A: Да, `LocalImageDisplay` автоматически различает локальные пути и URL.

**Q: Что делать со старыми Supabase URL?**
A: Либо игнорировать, либо мигрировать через функцию `migrateSupabaseImage()`.

**Q: Как очистить все фото?**
```dart
final storage = LocalStorageService();
await storage.clearBucket('events');
await storage.clearBucket('avatars');
```

**Q: Какой размер займет хранилище?**
```dart
final storageSize = await LocalStorageService().getStorageSize('events');
print('Размер: ${(storageSize / 1024 / 1024).toStringAsFixed(2)}MB');
```
