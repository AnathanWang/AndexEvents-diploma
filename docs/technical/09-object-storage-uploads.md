# 9. Объектное хранилище и загрузки файлов

## 9.1 MinIO в локальном Compose

- Сервис **`minio`** слушает **9000** (S3 API) и **9001** (консоль).
- Учётные данные root в compose: пользователь **`andexevents`**, пароль **`andexevents_minio_secret`**.
- Контейнер **`minio-init`** создаёт бакеты: **`avatars`**, **`events`**, **`photos`**, **`media`**.

## 9.2 Использование бакетов в upload-service

Код разрешает загрузку только в бакеты, перечисленные в **`AllowedBucket`** (`services/upload-service/internal/storage/minio.go`):

- `avatars`
- `events`
- `photos`

Бакет **`media`**, создаваемый init-скриптом, в текущей whitelist **не входит**. Если нужна загрузка в `media`, расширить `AllowedBucket` и согласовать с клиентом.

## 9.3 Поток загрузки

1. Клиент отправляет `POST /api/upload?bucket=<optional>` с `multipart/form-data`, поле **`file`**.
2. Middleware проверяет Firebase token и определяет пользователя.
3. Выбирается бакет (по умолчанию `events`), валидируется расширение и размер.
4. Объект записывается в MinIO под ключом **`{firebaseUid}/{generatedFilename}`**.
5. Формируется **`fileUrl`** для ответа клиенту.

## 9.4 Публичный URL (`fileUrl`)

При непустом **`UPLOADS_PUBLIC_BASE_URL`** (например `http://localhost` за Traefik без порта или `https://api.example.com`):

```
{UPLOADS_PUBLIC_BASE_URL}/uploads/{bucket}/{firebaseUid}/{filename}
```

Если переменная пустая, URL строится из запроса:

- протокол из `X-Forwarded-Proto` или TLS/HTTP;
- хост из `X-Forwarded-Host` или `Request.Host`;
- путь `/uploads/...`

Это важно при размещении за Traefik/Ingress: корректные forwarding-заголовки дают правильные абсолютные ссылки.

## 9.5 Публичная выдача файла

Маршрут приложения:

```
GET /uploads/:bucket/:userId/:filename
```

Traefik направляет префикс **`/uploads`** на upload-service. Здесь `:userId` в типичном случае соответствует **Firebase UID**, использованному при сохранении объекта.

## 9.6 Удаление фото

`DELETE /api/upload` с query-параметрами (см. `upload_handler.go`): минимум **`url`** (полный URL), **`bucket`** по умолчанию `photos`. Для бакета `photos` выполняется операция в БД (`RemoveUserPhoto`).

## 9.7 Связь с Java users-service

После загрузки аватара или фото профиля upload-service пытается обновить соответствующие поля пользователя через **`UserRepository`** в Go (jdbc/psql слой в том же сервисе). Рассинхрон при ошибке БД возможен — см. комментарии в коде загрузчика.
