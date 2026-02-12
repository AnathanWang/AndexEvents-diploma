# План разработки функционала Модерации и Админ-панели

## 1. База данных (PostgreSQL)

Поскольку в проекте используется микросервисная архитектура (Java/Spring для сервисов пользователей, событий и аутентификации), изменения в базе данных должны быть отражены через **Flyway миграции** в соответствующих сервисах, а не через Prisma.

### 1.1. Таблица `reports` (Сервис модерации или Users Service)
Необходимо создать новую таблицу для хранения жалоб. Рекомендуется создать отдельный микросервис `moderation-service` или добавить это в `users-service`.

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id),
    target_user_id UUID REFERENCES users(id),
    target_event_id UUID REFERENCES events(id), -- Если таблица events в той же БД
    reason VARCHAR(50) NOT NULL, -- SPAM, INAPPROPRIATE_CONTENT, etc.
    details TEXT,
    status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, RESOLVED, DISMISSED
    resolver_id UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
```

### 1.2. Обновление таблицы `users`
Добавить поле роли, если оно еще не существует (или использовать отдельную таблицу ролей/пермиссий).

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'USER';
-- Roles: USER, MODERATOR, ADMIN
```

## 2. Backend (Java/Spring + Go)

### 2.1. Authorization
В Java-сервисах (`auth-service-java`) необходимо обновить логику валидации токенов, чтобы включать роль пользователя в Claims или проверять её в БД при каждом запросе к админским эндпоинтам.

### 2.2. API Эндпоинты

#### В `users-service-java` (или новом `moderation-service`):
- `POST /api/reports` - Создать жалобу (доступно всем).
- `GET /api/admin/reports` - Список жалоб (только ADMIN/MODERATOR).
- `POST /api/admin/reports/{id}/resolve` - Решить жалобу.
- `GET /api/admin/users` - Список пользователей.
- `POST /api/admin/users/{id}/ban` - Забанить пользователя.

#### В `events-service-java`:
- `GET /api/admin/events/pending` - Очередь модерации событий.
- `POST /api/admin/events/{id}/approve` - Одобрить.
- `POST /api/admin/events/{id}/reject` - Отклонить.

## 3. Frontend (Flutter)
... (без изменений)

## 3. Frontend (Flutter)

Поскольку проект уже поддерживает Web (`web/` директория существует), админ-панель будет реализована как часть основного приложения, но доступная только пользователям с ролью `ADMIN` или `MODERATOR`.

### 3.1. Адаптация под Web
- Убедиться, что навигация удобна на больших экранах (использовать `LayoutBuilder` или адаптивные виджеты).

### 3.2. Функционал жалоб (Client Side)
Добавить возможность жаловаться на пользователей в приложении.

- **UserProfileScreen**: Добавить кнопку "Пожаловаться" в меню (три точки).
- **MatchScreen**: Добавить кнопку "Пожаловаться" в карточку пользователя.
- **ReportDialog**: Диалог с выбором причины (`ReportReason`) и полем для комментария.

### 3.3. Новые Экраны (Admin Zone)
Создать пакет `lib/presentation/admin/`.

- **AdminDashboardScreen**: Главная страница со статистикой (новые юзеры, ожидающие проверки события, активные жалобы).
- **UsersListScreen**: Таблица пользователей с поиском и действиями (бан/разбан).
- **EventModerationScreen**: Список карточек событий. Кнопки "Принять" / "Отклонить".
- **ReportsScreen**: Список тикетов с жалобами. Фильтрация по типу (на юзера / на событие). При нажатии — переход к деталям жалобы с возможностью забанить обвиняемого.

### 3.3. Логика навигации
- В `AuthBloc` или `UserBloc` сохранять роль текущего пользователя.
- В меню приложения добавить пункт "Админ-панель", который виден только если `user.role == 'ADMIN' || 'MODERATOR'`.

## 4. План внедрения

1.  **Backend: SQL Migrations (Flyway)**
    - Создать файл миграции `V2__add_roles_and_reports.sql` в `users-service/src/main/resources/db/migration`.
    - Добавить создание таблицы `reports` и колонки `role` в таблицу `users`.
2.  **Backend: Logic Implementation**
    - В `users-service` (Java):
        - Добавить сущность `Report` (JPA Entity).
        - Добавить `ReportRepository`.
        - Реализовать `AdminController` для работы с пользователями и репортами.
        - Добавить проверку ролей (например, через Spring Security `@PreAuthorize("hasRole('ADMIN')")`).
    - В `events-service` (Java):
        - Добавить эндпоинты для модерации событий.
3.  **Frontend: Logic**
    - Обновить модель `User` (добавить поле `role`).
    - Создать сервис `AdminService` для общения с новым API.
    - Создать сервис `ReportService` для отправки жалоб пользователями.
4.  **Frontend: UI**
    - Реализовать `ReportDialog` для отправки жалоб.
    - Реализовать экраны админ-панели (`AdminDashboard`, `ReportsList`, `UsersList`).
5.  **Тестирование**
    - Создать тестового админа через SQL (`UPDATE users SET role = 'ADMIN' ...`).
    - Проверить флоу отправки и обработки жалобы.
