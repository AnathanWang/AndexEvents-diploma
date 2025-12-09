-- ============================================
-- НАСТРОЙКА SUPABASE ДЛЯ РАЗРАБОТКИ
-- ============================================

-- ============================================
-- 1. ОТКЛЮЧИТЬ ПОДТВЕРЖДЕНИЕ EMAIL
-- ============================================
-- Способ 1: Через Dashboard (рекомендуется)
-- Перейдите в: Dashboard → Authentication → Providers → Email
-- Прокрутите вниз и отключите "Confirm email"

-- Способ 2: Подтвердить всех существующих пользователей вручную
-- ВНИМАНИЕ: Используйте только для разработки!
UPDATE auth.users
SET email_confirmed_at = NOW(),
    confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- Способ 3: Подтвердить конкретного пользователя
UPDATE auth.users
SET email_confirmed_at = NOW(),
    confirmed_at = NOW()
WHERE email = 'lola229@gmail.com';


-- ============================================
-- 2. НАСТРОИТЬ SUPABASE STORAGE
-- ============================================
-- Создайте bucket 'avatars' через Dashboard:
-- 1. Перейдите: Storage → Create bucket
-- 2. Название: avatars
-- 3. Public bucket: YES (включите)
-- 4. Нажмите Create

-- Или через SQL (если есть доступ):
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('avatars', 'avatars', true)
-- ON CONFLICT (id) DO NOTHING;


-- ============================================
-- 3. НАСТРОИТЬ RLS ПОЛИТИКИ ДЛЯ STORAGE
-- ============================================
-- Разрешить загрузку файлов только для авторизованных пользователей

-- Политика: Пользователи могут загружать файлы в свою папку
CREATE POLICY "Users can upload their own avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Политика: Пользователи могут обновлять свои файлы
CREATE POLICY "Users can update their own avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Политика: Пользователи могут удалять свои файлы
CREATE POLICY "Users can delete their own avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Политика: Все могут читать аватарки (публичный доступ)
CREATE POLICY "Public access to avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');
