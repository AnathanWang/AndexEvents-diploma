# 8. Аутентификация (Firebase)

## 8.1 Модель угроз на уровне API

- Клиент после входа через **Firebase Authentication** получает **ID Token** (JWT).
- Backend **не доверяет** телу запроса как доказательству личности; идентификация для защищённых операций строится на проверке JWT из заголовка:

```http
Authorization: Bearer <firebase-id-token>
```

## 8.2 Java-сервисы (Spring Boot)

Проверка подписи и метаданных токена выполняется через **JWKS** Firebase (класс вроде `FirebaseJwtVerifier` в каждом сервисе).

Конфигурация:

- **`FIREBASE_PROJECT_ID`** — идентификатор проекта Firebase (в compose подставляется из переменной окружения хоста или значение по умолчанию).
- **`FIREBASE_JWKS_URL`** — опциональное переопределение URL JWKS (если пусто, используется стандартная логика клиента/конфигурации в коде).

После успешной верификации цепочка фильтров заполняет контекст пользователя (internal user id и др.) для контроллеров.

**Примечание:** в `auth-service` присутствует код с именем `SupabaseJwtVerifier` — это наследие альтернативного провайдера; для описания текущего продукта ориентир — Firebase и JWKS.

## 8.3 Go-сервисы (match-service, upload-service)

Инициализация в `cmd/main.go`:

```go
firebase.NewClient(context.Background(), firebase.Config{
    CredentialsFile: cfg.FirebaseCredentialsFile,
    ProjectID:       cfg.FirebaseProjectID,
})
```

- Используется файл **сервисного аккаунта** Firebase (Admin SDK JSON).
- В Docker Compose файл монтируется с хоста:  
  `secrets/firebase-service-account.json` → `/app/firebase-credentials.json`
- Переменная **`FIREBASE_CREDENTIALS_FILE`** указывает путь внутри контейнера.

**match-service:** для HTTP используется `AuthMiddleware`, который извлекает Bearer token, верифицирует его через Firebase Admin API и помещает в контекст Gin значение **`dbUserID`** (и другие ключи по необходимости).

**upload-service:** группа `/api/upload` защищена `FirebaseAuthMiddleware`; в контекст записываются идентификаторы для связи с строкой пользователя в БД (`GetDBUserID`, `GetFirebaseUID`).

## 8.4 Клиент Flutter

Получение токена инкапсулировано в слое **`lib/core/`** (например провайдер / сервис для `getIdToken()`). HTTP-сервисы в `lib/data/services/` добавляют заголовок `Authorization` при вызовах защищённых эндпойнтов.

Настройка Firebase на устройстве: **`FIREBASE_SETUP.md`** в корне репозитория, файлы `google-services.json` и `GoogleService-Info.plist`.

## 8.5 Срок жизни токена и обновление

ID Token имеет ограниченный TTL. Клиент должен запрашивать актуальный token перед критичными запросами или обрабатывать `401` с повторной аутентификацией/refresh — конкретная реализация в `AuthBloc` и сервисах Firebase на стороне Flutter.
