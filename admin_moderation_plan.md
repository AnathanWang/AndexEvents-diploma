# План разработки функционала Модерации и Админ-панели

## 1. База данных (Prisma)

Необходимо расширить схему базы данных для поддержки системы жалоб и аудита действий администраторов.

### 1.1. Новая модель `Report`
Создать модель для хранения жалоб пользователей на события или других пользователей.

```prisma
enum ReportReason {
  SPAM
  INAPPROPRIATE_CONTENT
  HARASSMENT
  FAKE_EVENT
  OTHER
}

enum ReportStatus {
  PENDING
  RESOLVED
  DISMISSED
}

model Report {
  id          String       @id @default(uuid())
  
  reporterId  String
  reporter    User         @relation("ReportReporter", fields: [reporterId], references: [id])
  
  // Объект жалобы (либо пользователь, либо событие)
  targetUserId String?
  targetUser   User?       @relation("ReportTargetUser", fields: [targetUserId], references: [id])
  
  targetEventId String?
  targetEvent   Event?     @relation(fields: [targetEventId], references: [id])
  
  reason      ReportReason
  details     String?      @db.Text
  status      ReportStatus @default(PENDING)
  
  // Кто и когда решил проблему
  resolverId  String?
  resolver    User?        @relation("ReportResolver", fields: [resolverId], references: [id])
  resolvedAt  DateTime?
  
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt

  @@index([status])
  @@index([reporterId])
}
```

### 1.2. Обновление модели `User`
Добавить обратные отношения для репортов.

```prisma
model User {
  // ... существующие поля
  
  // Отношения для модерации
  sentReports      Report[] @relation("ReportReporter")
  receivedReports  Report[] @relation("ReportTargetUser") // Жалобы НА этого пользователя
  resolvedReports  Report[] @relation("ReportResolver")   // Жалобы, обработанные этим админом
}
```

## 2. Backend (Node.js/Express)

### 2.1. Middleware авторизации
Добавить middleware для проверки прав доступа.

- `requireRole(roles: UserRole[])`: Проверяет, есть ли у пользователя нужная роль (`ADMIN` или `MODERATOR`).

### 2.2. Admin API Endpoints
Создать новый роут `src/routes/admin.routes.ts`.

#### Управление пользователями
- `GET /admin/users` - список пользователей с пагинацией и фильтрами.
- `GET /admin/users/:id` - детальная инфо о пользователе (включая скрытые данные).
- `POST /admin/users/:id/ban` - заблокировать пользователя (можно добавить поле `bannedAt` в User).
- `POST /admin/users/:id/role` - изменить роль пользователя.

#### Модерация событий
- `GET /admin/events/pending` - список событий, требующих модерации.
- `POST /admin/events/:id/approve` - одобрить событие.
- `POST /admin/events/:id/reject` - отклонить событие (с указанием причины).

#### Система жалоб
- `GET /admin/reports` - список жалоб.
- `POST /admin/reports/:id/resolve` - закрыть жалобу (принять меры или отклонить).

## 3. Frontend (Flutter)

Поскольку проект уже поддерживает Web (`web/` директория существует), админ-панель будет реализована как часть основного приложения, но доступная только пользователям с ролью `ADMIN` или `MODERATOR`.

### 3.1. Адаптация под Web
- Убедиться, что навигация удобна на больших экранах (использовать `LayoutBuilder` или адаптивные виджеты).

### 3.2. Новые Экраны (Admin Zone)
Создать пакет `lib/presentation/admin/`.

- **AdminDashboardScreen**: Главная страница со статистикой (новые юзеры, ожидающие проверки события, активные жалобы).
- **UsersListScreen**: Таблица пользователей с поиском и действиями (бан/разбан).
- **EventModerationScreen**: Список карточек событий. Кнопки "Принять" / "Отклонить".
- **ReportsScreen**: Список тикетов с жалобами.

### 3.3. Логика навигации
- В `AuthBloc` или `UserBloc` сохранять роль текущего пользователя.
- В меню приложения добавить пункт "Админ-панель", который виден только если `user.role == 'ADMIN' || 'MODERATOR'`.

## 4. План внедрения

1.  **Backend: Schema & Migrations**
    - Изменить `schema.prisma`.
    - Выполнить `prisma migrate dev`.
2.  **Backend: Logic**
    - Реализовать `requireRole` middleware.
    - Реализовать `AdminController`.
    - Подключить роуты.
3.  **Frontend: Logic**
    - Обновить модель пользователя (добавить поле `role`).
    - Создать сервис `AdminService` для общения с новым API.
4.  **Frontend: UI**
    - Сверстать экран списка жалоб.
    - Сверстать экран модерации событий.
5.  **Тестирование**
    - Создать тестового админа через БД.
    - Проверить весь флоу: Пользователь создает репорт -> Админ видит репорт -> Админ принимает меры.
