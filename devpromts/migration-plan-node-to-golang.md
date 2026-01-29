# План миграции бэкенда с Node.js на Go микросервисы

## 📋 Обзор

**Цель**: Переписать Express.js бэкенд на Go микросервисную архитектуру **без изменения публичного API** (drop-in replacement).  
**Срок**: ~2 месяца  
**Текущий статус**: В процессе

**Ключевая установка миграции (важно)**:
- Go сервисы должны повторять **как в Node**: пути, методы, auth (Supabase JWT), query/body параметры, формат ответов `{ success, data, message }`, тексты сообщений/ошибок.
- Любые улучшения/новые endpoints/рефакторинг API делаем **после** достижения 100% совместимости с Node.
- Источник правды по контракту: `backend/src/routes/*` + `backend/src/controllers/*` + `backend/src/middleware/*`.

---

## 🏗️ Архитектура

### Исходная структура (Node.js/Express)

```
backend/src/
├── routes/
│   ├── event.routes.ts      → events-service
│   ├── user.routes.ts       → users-service  
│   ├── friend.routes.ts     → friends-service
│   ├── match.routes.ts      → match-service
│   └── upload.routes.ts     → upload-service
├── services/
│   ├── event.service.ts
│   ├── user.service.ts
│   ├── friend.service.ts
│   ├── match.service.ts
│   └── minio.service.ts
├── controllers/
├── middleware/
│   └── auth.middleware.ts   → shared/middleware
└── utils/
```

### Целевая структура (Go микросервисы)

```
services/
├── shared/                   # Общий код
│   ├── middleware/
│   │   └── auth.go          # Supabase JWT auth
│   ├── database/
│   │   └── postgres.go      # pgx pool
│   └── logger/
│       └── zap.go
├── auth-service/            # ✅ ГОТОВ (порт 8001)
├── events-service/          # ✅ ГОТОВ (порт 8002)
├── users-service/           # 🔄 В ПРОЦЕССЕ (порт 8003)
├── friends-service/         # 📋 TODO (порт 8004)
├── match-service/           # 📋 TODO (порт 8005)
└── upload-service/          # 📋 TODO (порт 8006)
```

---

## 📊 Статус миграции

| # | Сервис | Порт | Статус | Endpoints | Тесты |
|---|--------|------|--------|-----------|-------|
| 1 | **auth-service** | 8001 | ✅ Готов | 5 | ✅ 48-68% |
| 2 | **events-service** | 8002 | ✅ Готов | 9 | ✅ 100% |
| 3 | **users-service** | 8003 | 🔄 В процессе | 5 | 🔄 |
| 4 | **friends-service** | 8004 | 📋 TODO | 6 | - |
| 5 | **match-service** | 8005 | 📋 TODO | 5 | - |
| 6 | **upload-service** | 8006 | 📋 TODO | 2 | - |

---

## 📝 Детальный план по сервисам

### 1. ✅ Auth Service (ГОТОВ)

**Файл**: `services/auth-service/`

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/health` | GET | Health check |
| `/api/auth/verify` | POST | Верификация Supabase JWT |
| `/api/auth/register` | POST | Регистрация пользователя |
| `/api/auth/login` | POST | Логин (проверка токена) |
| `/api/auth/me` | GET | Текущий пользователь |

**Технологии**: Gin, JWT (`github.com/golang-jwt/jwt/v5`), pgx/v5, Zap

---

### 2. ✅ Events Service (ГОТОВ)

**Файл**: `services/events-service/`

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/events` | POST | ✅ | Создать событие |
| `/api/events` | GET | ❌ | Список событий (+ geo-поиск) |
| `/api/events/:id` | GET | ❌ | Получить событие |
| `/api/events/:id` | PUT | ✅ | Обновить событие |
| `/api/events/:id` | DELETE | ✅ | Удалить событие |
| `/api/events/user/:userId` | GET | ❌ | События пользователя |
| `/api/events/:id/participate` | POST | ✅ | Присоединиться |
| `/api/events/:id/participate` | DELETE | ✅ | Покинуть |
| `/api/events/:id/participants` | GET | ❌ | Список участников |

**PostGIS**: ST_DWithin, ST_Distance, ST_MakePoint

---

### 3. 🔄 Users Service (В ПРОЦЕССЕ)

**Файл**: `services/users-service/`

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/users` | POST | ✅ | Создать профиль |
| `/api/users/me` | GET | ✅ | Мой профиль |
| `/api/users/me` | PUT | ✅ | Обновить профиль |
| `/api/users/me/location` | PUT | ✅ | Обновить локацию |
| `/api/users/matches` | GET | ✅ | Найти матчи |

**Особенности**:
- PostGIS для геолокации
- Matching по интересам (array intersection)
- Supabase UID связка

---

### 4. 📋 Friends Service (TODO)

**Источник**: `backend/src/routes/friend.routes.ts`

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/friends` | GET | ✅ | Список друзей |
| `/api/friends/requests` | GET | ✅ | Входящие заявки |
| `/api/friends/requests/sent` | GET | ✅ | Исходящие заявки |
| `/api/friends/request/:userId` | POST | ✅ | Отправить заявку |
| `/api/friends/accept/:requestId` | POST | ✅ | Принять заявку |
| `/api/friends/reject/:requestId` | POST | ✅ | Отклонить заявку |

**Модели**:
- FriendRequest (status: PENDING, ACCEPTED, REJECTED)
- Friendship

---

### 5. 📋 Match Service (TODO)

**Источник**: `backend/src/routes/match.routes.ts`

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/matches` | GET | ✅ | Список взаимных матчей (возвращает пользователей “другую сторону” матча) |
| `/api/matches/actions?action=LIKE\|DISLIKE\|SUPER_LIKE&limit=50` | GET | ✅ | Мои действия по пользователям (как в Node) |
| `/api/matches/like` | POST | ✅ | Лайк `{ targetUserId }` |
| `/api/matches/dislike` | POST | ✅ | Дизлайк `{ targetUserId }` |
| `/api/matches/super-like` | POST | ✅ | Супер-лайк `{ targetUserId }` |

**Особенности**:
- Двусторонний матч (mutual like): взаимность считается, если обе стороны сделали `LIKE` или `SUPER_LIKE`
- API и сообщения должны совпадать с Node (legacy), чтобы фронт не менять
- Auth: Supabase JWT (как в `backend/src/middleware/auth.middleware.ts`), плюс маппинг `supabaseUid -> User.id` в БД

---

### 6. 📋 Upload Service (TODO)

**Источник**: `backend/src/routes/upload.routes.ts`

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/upload/image` | POST | ✅ | Загрузить изображение |
| `/api/upload/delete` | DELETE | ✅ | Удалить файл |

**Технологии**:
- MinIO / Supabase Storage
- Image processing (resize, compress)

---

## 🛠️ Технологический стек

### Go библиотеки

| Категория | Библиотека | Назначение |
|-----------|------------|------------|
| HTTP | `gin-gonic/gin` | Web framework |
| Database | `jackc/pgx/v5` | PostgreSQL driver |
| Auth | `golang-jwt/jwt/v5` | Supabase JWT (HMAC) |
| Logging | `uber-go/zap` | Structured logging |
| Testing | `stretchr/testify` | Test assertions |
| UUID | `google/uuid` | UUID generation |
| CORS | `gin-contrib/cors` | CORS middleware |

### Инфраструктура

- **Database**: PostgreSQL 15 + PostGIS
- **Auth**: Supabase JWT (как в Node, secret в `SUPABASE_JWT_SECRET`)
- **Storage**: Supabase Storage
- **Deployment**: Docker Compose → Kubernetes

---

## 📁 Структура каждого микросервиса

```
service-name/
├── cmd/
│   └── main.go              # Entry point
├── internal/
│   ├── config/
│   │   └── config.go        # Environment config
│   ├── model/
│   │   └── models.go        # Domain models
│   ├── repository/
│   │   └── repository.go    # Database layer
│   ├── service/
│   │   ├── service.go       # Business logic
│   │   └── service_test.go  # Unit tests
│   ├── handler/
│   │   ├── handler.go       # HTTP handlers
│   │   └── handler_test.go  # Integration tests
│   └── middleware/
│       ├── auth.go          # Auth middleware
│       ├── cors.go          # CORS
│       └── logger.go        # Request logging
├── go.mod
├── go.sum
├── Dockerfile
└── README.md
```

---

## 🔄 Порядок миграции

### Фаза 1: Core Services ✅
1. ✅ auth-service - базовая аутентификация
2. ✅ events-service - основной функционал

### Фаза 2: User Management 🔄
3. 🔄 users-service - профили и матчинг
4. 📋 friends-service - социальные связи

### Фаза 3: Advanced Features 📋
5. 📋 match-service - алгоритм матчинга
6. 📋 upload-service - файлы и изображения

### Фаза 4: Integration & Testing
7. API Gateway (опционально)
8. E2E тесты
9. Load testing
10. Documentation (Swagger)

---

## 🧪 Требования к тестированию

| Слой | Покрытие | Тип тестов |
|------|----------|------------|
| Repository | 60%+ | Unit (с моками) |
| Service | 80%+ | Unit |
| Handler | 70%+ | Integration |
| E2E | Основные сценарии | E2E |

---

## 📋 Чеклист для каждого сервиса

- [ ] Создать структуру директорий
- [ ] go.mod с зависимостями
- [ ] config/config.go
- [ ] model/*.go
- [ ] repository/*.go
- [ ] service/*.go + тесты
- [ ] handler/*.go + тесты
- [ ] middleware (auth, cors, logger)
- [ ] cmd/main.go
- [ ] Dockerfile
- [ ] README.md
- [ ] Тесты пройдены
- [ ] API протестировано вручную
- [ ] Закоммичено в Git

---

## 🚀 Команды для разработки

```bash
# Запуск сервиса
cd services/service-name
go run cmd/main.go

# Тесты
go test ./... -v

# Покрытие
go test ./... -cover

# Билд
go build -o service-name ./cmd

# Docker
docker build -t service-name .
```

---

## 📅 Timeline

| Неделя | Задачи |
|--------|--------|
| 1 | ✅ auth-service |
| 2 | ✅ events-service |
| 3 | 🔄 users-service |
| 4 | friends-service |
| 5 | match-service |
| 6 | upload-service |
| 7 | Integration, API Gateway |
| 8 | Testing, Documentation, Deploy |

---

## 📚 Документация

- [services/docs/auth-service.md](../services/docs/auth-service.md)
- [services/docs/events-service.md](../services/docs/events-service.md)
- [services/docs/architecture.md](../services/docs/architecture.md)
- [services/docs/api-reference.md](../services/docs/api-reference.md)

---

*Последнее обновление: Январь 2026*
