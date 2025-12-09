# Настройка Supabase Storage для аватарок

## Проблема
Timeout при загрузке файлов в Supabase Storage bucket 'avatars'

## Причины (по порядку вероятности)

### 1. ❌ Bucket не существует или не публичный
**Проверка:** Dashboard → Storage → Проверьте наличие bucket 'avatars'

**Решение:**
```
1. Storage → New bucket
2. Name: avatars
3. Public bucket: ✅ ДА (обязательно!)
4. Create bucket
```

### 2. ❌ Нет RLS политик для Storage
**Проверка:** Storage → avatars → Policies

**Решение (выполните в SQL Editor):**
```sql
-- Политика 1: Публичное чтение
CREATE POLICY "Public read avatars" 
ON storage.objects FOR SELECT 
TO public
USING (bucket_id = 'avatars');

-- Политика 2: Загрузка в свою папку
CREATE POLICY "Users upload own avatars" 
ON storage.objects FOR INSERT 
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Политика 3: Обновление своих файлов
CREATE POLICY "Users update own avatars" 
ON storage.objects FOR UPDATE 
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Политика 4: Удаление своих файлов
CREATE POLICY "Users delete own avatars" 
ON storage.objects FOR DELETE 
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

### 3. ❌ Проблемы с сетью/CORS
**Проверка:** 
- Откройте Chrome DevTools → Network
- Попробуйте загрузить файл
- Смотрите на запрос к `*.supabase.co/storage/v1/object/avatars/*`

**Если видите:**
- `CORS error` → Проблема с настройками CORS в Supabase
- `Failed to fetch` → Проблема с интернетом
- `Status 404` → Bucket не существует
- `Status 403` → Нет прав (RLS)
- `Status timeout` → Медленное соединение или большой файл

### 4. ❌ Файл слишком большой
**Проверка:** Посмотрите размер файла в логах Flutter

**Решение:**
- Ограничьте размер до 5MB
- Сжимайте изображения перед загрузкой

### 5. ❌ Неправильный путь к файлу
**Проверка:** Путь должен быть `{user_id}/filename.ext` без начального `/`

**Текущий код:**
```dart
final filePath = '${user.id}/$fileName'; // ✅ Правильно
```

## Быстрая диагностика

### Шаг 1: Проверьте bucket через curl
```bash
# Замените YOUR_PROJECT_URL и YOUR_ANON_KEY
curl -X POST 'https://rykbewslbfxltmipyseg.supabase.co/storage/v1/object/avatars/test.txt' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5a2Jld3NsYmZ4bHRtaXB5c2VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTM5NTUsImV4cCI6MjA3OTAyOTk1NX0.ps3cL3a1fOSG-JN8UQ1z0-WGA9nRTy8LI16nPFuQeJE' \
  -H 'Content-Type: text/plain' \
  -d 'test content'
```

**Ожидаемый результат:**
- ✅ `200/201` → Bucket работает
- ❌ `404` → Bucket не существует
- ❌ `403` → Нет прав

### Шаг 2: Проверьте в Supabase Dashboard
```
1. Storage → avatars
2. Попробуйте загрузить файл вручную через UI
3. Если не получается → bucket не настроен
```

### Шаг 3: Включите подробные логи Storage
В **Dashboard → Logs → Storage logs** смотрите ошибки при загрузке

## Текущая реализация в коде

### ✅ Что уже правильно:
- Проверка сессии и пользователя
- Правильный формат пути (`user_id/filename`)
- Timeout увеличен до 120 секунд
- Обработка StorageException

### ⚠️ Что нужно проверить:
1. Bucket 'avatars' существует в Dashboard
2. Bucket настроен как Public
3. Есть RLS политики (минимум 2)
4. Интернет соединение стабильное

## Следующие шаги

1. **Откройте Supabase Dashboard**
2. **Перейдите в Storage**
3. **Проверьте наличие bucket 'avatars'**
4. **Если нет - создайте (Public: YES)**
5. **Перейдите в SQL Editor**
6. **Выполните все 4 политики выше**
7. **Hot Restart Flutter приложения**
8. **Попробуйте загрузить фото**

## Если все равно не работает

Выполните команду для теста connectivity:
```bash
curl -v https://rykbewslbfxltmipyseg.supabase.co/storage/v1/bucket
```

И пришлите результат вместе с логами из Flutter.
