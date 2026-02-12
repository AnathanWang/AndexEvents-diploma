# План реализации системы жалоб и модерации

## Этап 1: Backend (Java/Spring)

### 1.1. Users Service (Core Logic)
Этот сервис будет отвечать за хранение и обработку жалоб, так как он владеет сущностями User и Report.

1.  **Entity & Repository**
    - Создать JPA сущность `Report` (в пакете `com.andexevents.usersservice.model`).
    - Создать `ReportRepository` с методами поиска по статусу.

2.  **Service Layer (`ReportService`)**
    - Метод `createReport(CreateReportRequest)`: Создание новой жалобы.
    - Метод `getReports(ReportStatus, Pageable)`: Получение списка жалоб (только для админов).
    - Метод `resolveReport(reportId, resolution, action)`: Изменение статуса жалобы.

3.  **Controllers**
    - **Public API**: `ReportController`
        - `POST /api/reports` — Эндпоинт для создания жалобы обычным пользователем.
    - **Admin API**: `AdminReportController`
        - `GET /api/admin/reports` — Список жалоб.
        - `POST /api/admin/reports/{id}/resolve` — Решение по жалобе (например, забанить пользователя + закрыть тикет).

4.  **Security**
    - Настроить SecurityConfig для проверки ролей. Эндпоинты `/api/admin/**` должны требовать роль `ADMIN` или `MODERATOR`.

### 1.2. Events Service
Необходимо добавить возможность администраторам модерировать события.

1.  **Admin Controller**
    - `POST /api/admin/events/{id}/status` — Изменить статус события (APPROVED / REJECTED).
    - При жалобе на событие, админ через Users Service получает ID события и вызывает этот метод в Events Service.

## Этап 2: Frontend (Flutter)

### 2.1. Инфраструктура
1.  **Models**: Создать Dart-модели `Report`, `ReportReason` (enum).
2.  **Services**:
    - `ReportService`: Методы `createReport`.
    - `AdminService`: Методы `getReports`, `resolveReport`, `banUser`.

### 2.2. Пользовательский интерфейс (User Side)
1.  **ReportDialog**:
    - Виджет диалогового окна с выбором причины (`Dropdown`) и полем комментария.
    - Кнопки "Отмена" и "Отправить".
2.  **Интеграция**:
    - В `UserProfileScreen`: Добавить пункт меню "Пожаловаться".
    - В `MatchCard`: Добавить иконку флага/восклицательного знака.

### 2.3. Админ-панель (Admin Side)
1.  **AdminLayout**: Базовый лейаут с боковым меню (Dashboard, Users, Reports).
2.  **ReportsListScreen**:
    - Список карточек с жалобами.
    - Фильтры по статусу (Pending/Resolved).
3.  **ReportDetailScreen**:
    - Информация о репортере и нарушителе.
    - Детали жалобы.
    - Кнопки действий: "Забанить пользователя", "Удалить контент", "Отклонить жалобу".

## Этап 3: Тестирование и Деплой
1.  **Manual Testing**:
    - Зайти под юзером А, отправить жалобу на юзера Б.
    - Зайти под Админом, увидеть жалобу.
    - Принять меры (бан), убедиться что статус обновился.

## Чек-лист реализации

- [x] **База данных**: Миграция создана (`V3__add_reports.sql`).
- [ ] **Backend**: Сущность `Report` и Репозиторий.
- [ ] **Backend**: Сервис и Контроллер создания жалоб.
- [ ] **Backend**: Админский API для просмотра и решения.
- [ ] **Frontend**: Сервис `ReportService`.
- [ ] **Frontend**: UI Диалог отправки жалобы.
- [ ] **Frontend**: UI Админ-панели.
