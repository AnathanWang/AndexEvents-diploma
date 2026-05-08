# Итоги за 2026‑05‑05

Ниже — полный список изменений/функций, которые мы внедрили сегодня в AndexEvents (Flutter + backend + инфраструктура).

## UI / UX (glassmorphism, единый стиль)

- **Новый дизайн админ‑экранов по `docs/ui_design_context.md`**:
  - `lib/presentation/admin/screens/admin_audit_logs_screen.dart`
  - `lib/presentation/admin/screens/event_moderation_screen.dart`
  - `lib/presentation/admin/screens/reports_screen.dart` (исправили дублирование заголовка/стрелки назад)
  - `lib/presentation/admin/screens/users_list_screen.dart` (карточка пользователя сделана компактнее, кнопки ровнее, роль/санкции уложены без пустот)
- **Новые переиспользуемые админ‑компоненты**:
  - `lib/presentation/admin/widgets/admin_card.dart`
  - `lib/presentation/admin/widgets/admin_pill.dart`
  - `lib/presentation/admin/widgets/admin_state_view.dart`
  - `lib/presentation/admin/widgets/admin_screen_scaffold.dart`

## Матчи (обновлённый UI + фиксы перекрытия)

- **Редизайн `MatchesScreen` и `EventMatchScreen` под новый UI**:
  - `lib/presentation/home/screens/matches_screen.dart`
  - `lib/presentation/matches/screens/event_match_screen.dart`
- **Фикс перекрытия карточек нижней навигацией**: добавлены корректные нижние отступы под высоту bottom nav, чтобы карточки/контент не «наезжали».
- **В `EventMatchScreen` добавлен компактный glass‑header события** (название/дата/GOING), чтобы контекст был виден сразу.

## Карта / лента / поиск

- **Фикс `RenderFlex overflow` на карте**:
  - `lib/presentation/home/screens/map_explore_screen.dart` — переработан проблемный `Row` (использованы `Expanded/Flexible`, `maxLines: 1`, `ellipsis`).
- **«Умные фильтры» для ленты**:
  - `lib/presentation/widgets/event_filters.dart` — расширены опции (включая цена/формат) и логика подсчёта активных фильтров.
  - `lib/presentation/home/screens/events_feed_screen.dart` — фильтрация по датам/категориям/цене/формату + сортировки; расширен текстовый поиск.
- **Текстовый поиск расширен**:
  - `lib/presentation/home/screens/events_feed_screen.dart` — теперь ищем по `title` + `description`.
  - `lib/presentation/home/screens/search_screen.dart` — поиск по `title/description/location/category`.
- **Кнопка фильтров на карте убрана по просьбе**:
  - `lib/presentation/home/screens/map_explore_screen.dart` — удалён UI фильтров и связанная логика; оставлены поиск по запросу и базовая сортировка.

## Экран создания события: большой редизайн + багфиксы

- **Полный редизайн `CreateEventScreen`**:
  - `lib/presentation/events/screens/create_event_screen.dart` — «продуктовый» glassmorphism‑UI, аккуратные секции, улучшенная компоновка.
- **Исправлены UX‑проблемы**:
  - верхняя плашка/контент больше не наезжает на заголовки;
  - после выбора обложки можно добавлять дополнительные фото (вернули кнопку/тайл добавления);
  - иконка/заголовок секции описания выровнены;
  - категории: снова multi‑select + возможность добавить свою категорию;
  - место проведения: ввод через выбор на карте; при переключении в онлайн очищаем оффлайн‑адрес;
  - если «Бесплатно» — поле цены полностью скрывается.

## Выбор места на карте

- **Редизайн `MapLocationPicker` под новый UI**:
  - `lib/presentation/events/screens/map_location_picker.dart`
- **Удалён поиск адреса** — осталась только карта и выбор точки (по запросу).

## Жалобы/модерация/санкции событий

- **Жалоба на событие из `RealEventDetailScreen`**:
  - `lib/presentation/events/screens/real_event_detail_screen.dart` — добавлена кнопка «пожаловаться» и открытие диалога.
- **Санкции событий**:
  - backend: таблица санкций + сервис/репозиторий/контроллер.
  - frontend: модель + сервис и UI в админке (`EventModerationScreen`) для просмотра/выдачи/отзыва санкций.
- **Поведение `HIDE_VISIBILITY`**:
  - события скрываются из публичных лент/карты, но остаются видимыми в модерации/админке (и логика возврата после истечения санкции через `expiresAt`).

## Календарь (Add to Calendar)

- **Добавлена кнопка “Add to Calendar” на экране события**:
  - `lib/presentation/events/screens/real_event_detail_screen.dart`
- **Новый сервис календаря**:
  - `lib/data/services/calendar_service.dart` — добавление события (title/description/start/end/location) + дефолтное напоминание (1 час), проверки платформ, улучшенная обработка ошибок.
- **Права платформ**:
  - `ios/Runner/Info.plist` — добавлен `NSCalendarsUsageDescription`.
  - `android/app/src/main/AndroidManifest.xml` — добавлены `READ_CALENDAR`/`WRITE_CALENDAR`.
- **Разбор `MissingPluginException`**: учтены ограничения платформ (web/desktop) и необходимость полного перезапуска после подключения плагина.

## Авто‑обновления UI после действий пользователя

- **После создания события обновляются лента и карта**:
  - `lib/presentation/home/home_shell.dart` — `CreateEventScreen` возвращает результат; при успехе инициируем `EventsLoadRequested` для BLoC карты и ленты; также обновление при переключении вкладок.
- **Участие в событии обновляет детали/количество участников**:
  - `lib/presentation/events/bloc/event_bloc.dart` — улучшена обработка ошибок (чистые сообщения с backend), чтобы UI корректнее показывал причину отказа и обновлял состояние после успешных действий.

## Черновики событий (локально, несколько черновиков)

- **Полноценные multiple drafts для `CreateEventScreen`**:
  - `lib/data/models/event_draft_model.dart` — модель черновика.
  - `lib/data/services/event_draft_service.dart` — хранение/список/rename/delete/upsert в `SharedPreferences` + совместимость со старым single‑draft форматом.
  - `lib/presentation/events/screens/create_event_screen.dart` — UX восстановления/выбора черновика при входе, ручное сохранение с именем, удаляется только **использованный** черновик после успешного создания события.

## Управление участниками события (организатор)

### Backend (events-service)

- **Миграция БД**:
  - `services-java/events-service/src/main/resources/db/migration/V6__event_participant_management.sql`
  - Добавлено: `WaitlistStatus` enum; таблицы `EventParticipantBan`, `OrganizerBlock`, `WaitlistEntry`, `ParticipantCheckIn`.
- **Репозитории**:
  - `EventParticipantBanRepository.java`
  - `OrganizerBlockRepository.java`
  - `WaitlistRepository.java`
  - `CheckInRepository.java`
- **Бизнес‑логика**:
  - `services-java/events-service/src/main/java/com/andexevents/events/service/EventService.java` — kick/ban/block/waitlist/check‑in, интеграция с `participate` (бан/лист ожидания при лимите), список глобально заблокированных.
  - `services-java/events-service/src/main/java/com/andexevents/events/repo/EventRepository.java` — добавлен `countGoingParticipants(String eventId)` и изменения по выдаче/фильтрации.
- **REST контроллеры (новые)**:
  - `EventParticipantManagementController.java`
  - `WaitlistController.java`
  - `OrganizerBlockController.java`
- **Auth requiredPaths обновлены**:
  - `services-java/events-service/src/main/resources/application.yml` — добавлены новые пути для управления участниками/банами/блоклистом/ожиданием/check‑in.
- **Исправлены ошибки компиляции контроллеров**:
  - приведены return types к `ResponseEntity<ApiResponse<Void>>` там, где возвращается только message.

### Flutter (UI + сервисы)

- **Модели**:
  - `lib/data/models/managed_participant_model.dart`
  - `lib/data/models/waitlist_entry_model.dart`
  - `lib/data/models/user_preview_model.dart`
- **Сервис API**:
  - `lib/data/services/event_participants_manage_service.dart`
- **UI организатора**:
  - `lib/presentation/events/screens/real_event_detail_screen.dart` — добавлена кнопка “Управление” (только создателю) + bottom sheet `_EventManageParticipantsSheet`:
    - вкладки: участники / ожидание / блоклист
    - действия: kick, ban/unban на событии, глобальный block/unblock, approve/reject waitlist, toggle check‑in.

## Документация

- **Актуализирован список “чего не хватает”**:
  - `docs/product_missing_features.md` — вычеркнули календарь из missing features и поправили форматирование (markdownlint).

## Инфраструктура / Docker

- **Пересборка `events-service`** (Docker Compose) выполнена сегодня:
  - миграция `V6` успешно применена при старте (Flyway).

