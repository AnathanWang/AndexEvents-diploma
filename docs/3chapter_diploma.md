3 Проектирование программного продукта

> **Схемы и диаграммы** вынесены в отдельный файл `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`: Use-Case (UML-нотация), DFD, ER-модель по миграциям Flyway, IDEF0 (контекстная A-0 и декомпозиция A0). Ниже — текст главы со ссылками на рисунки по номеру; для вставки в Word экспортируйте блоки из файла схем в PNG.

3.1 Архитектура программного решения

В рамках реализации программного продукта была выбрана микросервисная многоуровневая архитектура клиент-серверного типа. Такое архитектурное решение обеспечивает высокую масштабируемость, отказоустойчивость, удобство разработки и сопровождения системы.

Система разделена на несколько независимых слоёв и компонентов, каждый из которых выполняет строго определённые функции и несёт чёткую ответственность:

клиентский слой — кроссплатформенное мобильное приложение, обеспечивающее взаимодействие пользователей с системой. Приложение не содержит основной бизнес-логики обработки данных и полностью отделено от серверной части;

API-шлюз — единая точка входа для всех HTTP-запросов, выполняющий проксирование и маршрутизацию обращений на целевые микросервисы;

сервисный слой (основная бизнес-логика) — модули управления пользователями, событиями, аутентификацией и разграничением доступа;

сервисный слой (высоконагруженные операции) — выделенные модули обработки свайпов и загрузки медиаконтента;

слой хранения данных — единая реляционная база данных с пространственным расширением, разделённая на логические схемы по принципу Single Database, Multiple Schemas;

объектное хранилище — хранение фотографий профилей и медиаматериалов событий;

кэш — временное хранилище для ускорения отдельных операций при масштабировании нагрузки.

Особое внимание уделено разделению ответственности между компонентами и возможности независимого масштабирования. Такой подход позволяет расширять функциональность и поддерживать систему при росте числа пользователей и объёма геопривязанного контента без значительного рефакторинга базового кода.

Микросервисная архитектура также упрощает интеграцию с внешним провайдером аутентификации и обеспечивает надёжную работу системы в условиях одновременного геопоиска событий, формирования ленты рекомендаций и обработки пользовательских свайпов.

На рисунке 3.1 представлена общая архитектурная схема программного комплекса Andex Events.

Рисунок 3.1 – Архитектура программного комплекса Andex Events *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.1)*

3.2 Процессы системы

3.2.1 Регистрация, авторизация пользователя и разграничение прав доступа

В клиентском приложении аутентификация реализована через Firebase Authentication. При запуске `AndexApp` инициализирует `AuthBloc`, который проверяет наличие текущей сессии Firebase. Если пользователь не авторизован, отображается `OnboardingScreen` с переходом на `LoginScreen` / `RegisterScreen`. При успешном входе `AuthBloc` запрашивает профиль через `GET /api/users/me` и определяет маршрут:

если `emailVerified = false` — `EmailVerificationScreen`;

если `isOnboardingCompleted = false` — `SetupProfileScreen` (первый шаг онбординга);

иначе — `HomeShell` (главный экран с четырьмя вкладками).

Все защищённые HTTP-запросы к backend отправляются с заголовком `Authorization: Bearer <Firebase ID Token>`. На сервере Java-сервисы (`users-service`, `events-service`, `auth-service`) и Go-сервисы (`match-service`, `upload-service`) верифицируют JWT по JWKS Firebase, извлекают `firebaseUid` и сопоставляют его с записью `users."User"`.

Проверка роли выполняется на backend: доступ к модерации событий, жалобам и санкциям имеют только пользователи с ролями MODERATOR и ADMIN. Статус онбординга кэшируется локально в `AuthService` для быстрого старта при временной недоступности API.

На рисунке 3.2 представлена Use-Case диаграмма авторизации и управления правами доступа.

Рисунок 3.2 – Use-Case «Авторизация и разграничение прав доступа» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.2)*

3.2.2 Заполнение профиля и прохождение онбординга

Онбординг реализован тремя последовательными экранами Flutter-приложения:

**Шаг 1 — `SetupProfileScreen`:** пользователь указывает возраст, пол и при желании загружает фото. Аватар отправляется через `POST /api/upload?bucket=avatars`, затем URL дублируется в профиле через `PUT /api/users/me` (`photoUrl`). Шаг можно пропустить без заполнения полей.

**Шаг 2 — `SetupInterestsScreen`:** выбор минимум трёх интересов из фиксированного списка (Музыка, Спорт, IT и др.). Данные сохраняются `PUT /api/users/me` с полем `interests`. Без трёх интересов переход заблокирован.

**Шаг 3 — `SetupLocationScreen`:** запрос разрешения Geolocator, получение координат и отправка `PUT /api/users/me/location`. Затем вызывается `PUT /api/users/me` с `isOnboardingCompleted: true`, статус кэшируется в `AuthService`, выполняется переход на `HomeShell`. Кнопка «Пропустить» также завершает онбординг без координат.

Пока `isOnboardingCompleted = false`, `AndexApp` и `LoginScreen` не допускают пользователя на главный экран.

На рисунке 3.3 представлена Use-Case диаграмма прохождения онбординга.

Рисунок 3.3 – Use-Case «Онбординг пользователя» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.3)*

3.2.3 Обновление геолокации пользователя

После входа в `HomeShell` запускается синглтон `LocationSyncService`. Он реализует непрерывную синхронизацию координат с backend:

при `initState` вызывается `LocationSyncService.start()` — немедленный `syncNow(reason: 'startup')` и подписка на `Geolocator.getPositionStream` с `distanceFilter: 50`;

функция `shouldSyncLocation` отправляет координаты при первом запуске, при смещении ≥ 50 м или не реже одного раза в 30 секунд;

каждая синхронизация — `PUT /api/users/me/location` с `{ latitude, longitude }`;

`HomeShell` реализует `WidgetsBindingObserver`: при `AppLifecycleState.resumed` — `syncNow` + `start`, при `paused`/`hidden` — `stop()` (фоновая геолокация не держится);

при `dispose` HomeShell сервис останавливается.

Backend (`users-service`) сохраняет `lastLatitude`, `lastLongitude`, `lastLocationUpdate` в таблице `users."User"`. Эти поля используются `MatchesScreen` при запросе `**GET /api/users/matches`** (параметры `latitude`, `longitude`, `radiusKm` из профиля). Для событий координаты пользователя на карте берутся отдельно через `Geolocator` в `YandexMapWidget` и не подменяют серверные поля профиля.

На рисунке 3.4 представлена Use-Case диаграмма обновления геолокации.

Рисунок 3.4 – Use-Case «Обновление геолокации» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.4)*

3.2.4 Публикация события и модерация

Пользователь нажимает «+» в `HomeShell` и открывает `CreateEventScreen`. Заполняет название, описание, категорию, дату, место (через `MapLocationPicker` или вручную), цену и при необходимости загружает до 5 фотографий через `POST /api/upload?bucket=events`. По кнопке «Опубликовать» клиент вызывает `EventBloc` → `POST /api/events`.

В текущей реализации событие **публикуется сразу**: `events-service` при создании записывает его со статусом `APPROVED`, и оно немедленно попадает в публичную выборку (`GET /api/events`, лента на `MapExploreScreen` и `EventsFeedScreen`). Предварительного одобрения модератором перед публикацией нет.

Модерация носит **реактивный** характер: после публикации пользователи могут подать жалобу (`Report`), а модератор или администратор в `EventModerationScreen` просматривает события вместе с жалобами (`GET /api/events/moderation/all`), удаляет нарушающий контент, закрывает жалобы (RESOLVED / DISMISSED) и при необходимости назначает санкции на событие (`EventSanction`: скрытие, заморозка участия, ограничение редактирования).

На рисунке 3.5 представлена Use-Case диаграмма публикации и модерации события.

Рисунок 3.5 – Use-Case «Публикация события и постмодерация» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.5)*

3.2.5 Поиск и отображение событий (карта и лента)

Карта и лента используют **разные сценарии загрузки**: карта подгружает события по видимой области при движении камеры, лента загружает общий список с клиентскими фильтрами.

**Вкладка «Карта» (`MapExploreScreen`) — подгрузка по viewport.**

После создания карты `YandexMapWidget` вызывает `getVisibleRegion()`. Утилита `map_viewport_utils` вычисляет центр видимой области и радиус в метрах (от центра до углов экрана + буфер 25 %, минимум 1 500 м). Фиксированного `maxDistance` на клиенте нет — радиус зависит от зума.

`EventBloc` отправляет запрос:

`GET /api/events?latitude=<центр>&longitude=<центр>&maxDistance=<радиус viewport>&limit=80`

На backend `events-service` выполняет PostGIS `ST_DWithin` / `ST_Distance` по полю `locationGeo`, возвращает только `status = APPROVED` офлайн-события без активной санкции `HIDE_VISIBILITY`.

При перемещении или изменении масштаба карты срабатывает `onCameraPositionChanged` (после завершения жеста, debounce 350 мс). Новый запрос отправляется, если центр камеры сместился более чем на ~35 % предыдущего радиуса. Новые события **добавляются** к уже загруженным (`mergeWithExisting: true`), а не заменяют список — пользователь видит накопленные мероприятия по мере исследования карты.

На экране отображаются только маркеры, попадающие в **текущий** viewport (`isPointInsideVisibleRegion`). Нижняя панель `MapNearbyEventsHub` показывает те же видимые события с клиентским текстовым поиском и сортировкой по близости к пользователю.

**Вкладка «Лента» (`EventsFeedScreen`) — полный список.**

При открытии вызывается `EventsLoadRequested()` без координат → `GET /api/events?page=1&limit=20`. Backend возвращает `listAllApproved`. Первая страница кэшируется в `SharedPreferences`.

Далее фильтрация **на клиенте**: город (по подстроке в `location` или в радиусе ~120 км от выбранного города), дата (сегодня / неделя / месяц), категория, цена, формат (онлайн / офлайн), текстовый поиск. Сортировка: по рейтингу, числу участников или по дате.

На рисунке 3.6 представлена Use-Case диаграмма геолокационного поиска событий.

Рисунок 3.6 – Use-Case «Поиск и отображение событий» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.6)*

3.2.6 Участие в событии

Участие реализовано на экране `RealEventDetailScreen` (открывается с карты, ленты или поиска). Пользователь может выбрать **два независимых действия**:

**«Интересно»** (`INTERESTED`) — сохранить событие в избранное без обязательства идти;

**«Пойду»** (`GOING`) — подтвердить участие в мероприятии.

**Клиентский поток.** Нажатие кнопки → `EventBloc` → проверка, что событие не завершено (`actualEndDateTime`) → `POST /api/events/{eventId}/participate` с телом `{ "status": "INTERESTED" | "GOING" }` и Bearer Token. После успеха bloc перезагружает карточку (`GET /api/events/{eventId}`), обновляя поля `isParticipating` и `userParticipationStatus`. Повторное нажатие отменяет участие: `DELETE /api/events/{eventId}/participate`.

**Проверки на backend (`events-service`).** Перед записью в `events."Participant"`:

событие должно иметь `status = APPROVED`;

пользователь не должен быть в `EventParticipantBan` на это событие;

пользователь не должен быть в блок-листе организатора (`OrganizerBlock`);

не должна действовать санкция `FREEZE_PARTICIPATION` на событие;

при `GOING` и заполненном `maxParticipants` — если лимит достигнут, пользователь добавляется в `WaitlistEntry` (статус PENDING), а API возвращает ошибку с текстом о листе ожидания.

Запись сохраняется через `upsertParticipation` (INSERT в `Participant` или UPDATE статуса при повторном запросе). Уникальная пара `userId` + `eventId`.

**Использование данных об участии.**

`GET /api/events/{eventId}/participants` — список участников с профилями;

счётчик `participantsCount` / `goingCount` в карточке события;

`EventMatchScreen` — лента знакомств среди участников со статусом `GOING` на конкретном событии;

организатор в `EventManageParticipantsSheet` — чек-ин (`ParticipantCheckIn`), исключение, одобрение листа ожидания.

На рисунке 3.7 представлена Use-Case диаграмма участия в событии.

Рисунок 3.7 – Use-Case «Участие в событии» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.7)*

3.2.7 Обработка свайпов и генерация взаимного совпадения

Матчинг реализован на вкладке **«Знакомства»** (`MatchesScreen`, index 2 в `HomeShell`) и дублируется в контексте события на экране `EventMatchScreen`. Оба экрана используют колоду `MatchSwipeDeck` и общий набор API `match-service`, но формируют ленту кандидатов по-разному.

**Доступ к вкладке.** При открытии `MatchesScreen` загружается текущий пользователь (`GET /api/users/me`). Если `isOnboardingCompleted = false`, показывается заглушка с переходом в редактирование профиля; свайпы недоступны до завершения онбординга (имя, фото, интересы, геолокация).

**Формирование ленты кандидатов (глобальный матчинг).** После успешного онбординга клиент вызывает `UserService.getOtherUsers()` → `GET /api/users/matches` с параметрами `limit` (по умолчанию 20), `latitude`, `longitude`, `radiusKm` (по умолчанию 50) из полей `lastLatitude` / `lastLongitude` профиля.

На стороне `users-service` (`UserRepository.findMatches`) кандидаты отбираются по условиям:

исключение самого пользователя;

`isOnboardingCompleted = true`, `isProfileVisible = true`, `showInMatches = true`;

пользователи в `incognitoMode` скрыты, кроме случая, когда они уже поставили текущему пользователю `LIKE`;

географический фильтр — bounding box вокруг точки (`lastLatitude`/`lastLongitude` в пределах `radiusKm`);

возрастной диапазон текущего пользователя (`minAge`, `maxAge`);

исключение взаимных блокировок (`users."UserBlock"` в обе стороны).

На клиенте из ответа дополнительно убираются: сам пользователь, уже взаимные мэтчи (`getMutualMatches` → `GET /api/matches`) и просмотренные профили (`MatchSeenService` — список ID в `SharedPreferences` по ключу `seen_match_user_ids:{userId}`). Оставшиеся `UserModel` конвертируются в `MatchPreview` с расчётом процента совпадения интересов.

**Матчинг в контексте события.** `EventMatchScreen` не вызывает `/users/matches`: он загружает участников события (`GET /api/events/{eventId}/participants`), оставляет только статус `GOING`, подгружает профили через `GET /api/users/{id}` и применяет тот же локальный фильтр `MatchSeenService`. При отправке свайпа в тело запроса добавляется `eventId`, чтобы запись в таблице `Match` была привязана к событию.

**Жесты в `MatchSwipeDeck`.** Пороговые значения смещения карточки:

свайп **вправо** (> 40 % ширины экрана) — `LIKE`;

свайп **влево** — `DISLIKE`;

свайп **вверх** — `SUPER_LIKE` (в UI — «Отложить / подумаю»);

свайп **вниз** — открыть полный профиль (`UserProfileScreen`), без записи действия на сервере.

Кнопки под колодой дублируют like, dislike и super-like.

**Отправка действия на сервер.** После жеста `MatchesScreen` / `EventMatchScreen` вызывают:

`POST /api/matches/like` — тело `{ "targetUserId": "...", "eventId": "..."? }`;

`POST /api/matches/dislike` — то же тело;

`POST /api/matches/super-like` — то же тело.

Запросы идут с Firebase Bearer Token через API-шлюз в Go-сервис `match-service`.

**Логика на backend (`match-service`).** Метод `CreateOrUpdateMatch` ищет или создаёт запись в `public."Match"` по паре пользователей и опциональному `eventId`. Действие текущего пользователя записывается в `userAAction` или `userBAction`. Взаимность (`isMutual = true`, `matchedAt`) наступает, когда **оба** действия относятся к like-типу — `LIKE` или `SUPER_LIKE` (метод `IsLikeType()`). `DISLIKE` с любой стороны не образует мэтч. При одностороннем like-типе сервис может отправить push-уведомление о входящем лайке (`NotifyIncomingLike`).

**После свайпа на клиенте.** Независимо от ответа сервера профиль помечается просмотренным: `MatchSeenService.markSeen(currentUserId, targetUserId)`, чтобы не показывать его повторно в колоде. Кнопка «Обновить подборку» сбрасывает локальный список seen (`clear`) и перезагружает кандидатов.

**Отображение результатов.**

`GET /api/matches` — взаимные мэтчи; подгружаются в `HomeShell._loadMutualMatches` и во вкладку «Взаимные» в `ProfileScreen`;

`GET /api/matches/incoming-likes` — входящие лайки без взаимности;

`GET /api/matches/actions?action=LIKE|DISLIKE|SUPER_LIKE` — исходящие действия по категориям (в профиле `SUPER_LIKE` отображается как «Отложил»).

Пользователь из взаимных мэтчей исключается из остальных вкладок профиля, чтобы не дублироваться в списках.

На рисунке 3.8 представлена Use-Case диаграмма обработки свайпов.

Рисунок 3.8 – Use-Case «Обработка свайпов и взаимного совпадения» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.8)*

3.2.8 Загрузка медиаконтента

Загрузка изображений вынесена в отдельный Go-сервис `upload-service` (MinIO). На клиенте единая точка входа — синглтон `LocalStorageService`, через который работают `UserService` (профиль) и `EventService` (события). Альтернативный класс `ProgressUploadService` в основных экранах не используется.

**Выбор файла.** Пользователь выбирает изображение через `ImagePicker` (галерея; на создании события — `pickMultiImage` до 5 файлов). Перед отправкой `LocalStorageService` сжимает файл утилитой `ImageUtils.compressImage` (`flutter_image_compress`, JPEG, quality ≈ 70, минимум 512×512) и проверяет размер на клиенте.

**HTTP-запрос.** Сжатый файл отправляется multipart POST на `POST /api/upload?bucket={bucket}` с полем `file` и заголовком `Authorization: Bearer <Firebase ID Token>`. Допустимые bucket: `avatars`, `photos`, `events`.


| Bucket    | Назначение в приложении                                   | Лимит (клиент / сервер) |
| --------- | --------------------------------------------------------- | ----------------------- |
| `avatars` | основной аватар профиля                                   | 5 MB / 5 MB             |
| `photos`  | дополнительные фото профиля, обложка (`uploadCoverPhoto`) | 5–6 MB / 10 MB          |
| `events`  | фото события                                              | 10 MB / 10 MB           |


**Обработка на `upload-service`.** Сервис верифицирует Firebase JWT, сопоставляет `firebaseUid` с `users."User".id`, проверяет расширение (`.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`) и размер, сохраняет объект в MinIO по пути `{firebaseUid}/{timestamp}-{random}.ext` и возвращает JSON `{ "success": true, "fileUrl": "…/uploads/{bucket}/{firebaseUid}/{filename}" }`. Публичная раздача — `GET /uploads/{bucket}/{userId}/{filename}` (проксируется Traefik).

**Побочные эффекты на сервере (важно для профиля).**

`bucket=avatars` — `upload-service` **сам** обновляет `users."User"."photoUrl"` в PostgreSQL;

`bucket=photos` — **сам** добавляет URL в массив `users."User".photos` (`AddUserPhoto`);

`bucket=events` — в БД событий **не пишет**; URL только возвращается клиенту.

Клиент нормализует `fileUrl`, если сервер вернул `localhost` (подмена host на `AppConfig.baseUrl` для физических устройств).

**Сценарии в UI.**

*Онбординг (`SetupProfileScreen`).* При выборе фото → `uploadProfilePhoto` (`avatars`) → `PUT /api/users/me` с `photoUrl` (дублирование уже выполненного сервером обновления). При ошибке загрузки онбординг продолжается без фото.

*Профиль (`ProfileBloc`, `EditProfileScreen`).* Смена аватара: upload → `updateProfile(photoUrl: …)` → перезагрузка `GET /api/users/me`. Дополнительные фото: `uploadAdditionalPhoto` (`photos`) — сервер уже добавил в `photos`, клиент перечитывает профиль. Удаление доп. фото: `DELETE /api/upload?bucket=photos&url=…` (убирает URL из массива `photos` в БД). Редактирование профиля пакетно загружает новый аватар, доп. фото и обложку (`uploadCoverPhoto` тоже в bucket `photos`), затем `PUT /api/users/me` с полями `photoUrl`, `coverImageUrl`, `photos`.

*События (`CreateEventScreen`, `EditEventScreen`).* `ImagePicker` → `EventBloc` / `EventPhotoUploadRequested` → `EventService.uploadEventPhoto` (`events`). Полученные URL накапливаются в `_uploadedPhotoUrls`. При публикации передаются в `POST /api/events` (или `PUT` при редактировании) как `imageUrl` (первое фото) и `imageUrls` (весь список). Между выбором и созданием события медиа уже лежат в MinIO, но привязка к событию происходит только при сохранении карточки.

На рисунке 3.9 представлена Use-Case диаграмма загрузки медиаконтента.

Рисунок 3.9 – Use-Case «Загрузка медиаконтента» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.9)*

3.2.9 Формирование ленты рекомендаций матчинга

«Лента рекомендаций» в приложении — это **колода карточек** `MatchSwipeDeck` на вкладке «Знакомства» (`MatchesScreen`) и аналогичный экран `EventMatchScreen` внутри карточки события. ML-модель не используется: реализовано **правило-ориентированное ранжирование** (`MatchRecommendationScorer` на backend, `MatchRecommendationUtils` на клиенте для ленты события) по факторам: входящий лайк → общие события со статусом `GOING` → число общих интересов → расстояние (haversine) → полнота профиля (бонусы и штрафы). Процент на карточке (`MatchPreview`) — визуализация пересечения интересов (Jaccard), не отдельная ML-метрика.

**Предусловия.** Лента грузится только при `isOnboardingCompleted = true`. Координаты для глобального матчинга берутся из `lastLatitude` / `lastLongitude` профиля (обновляются `LocationSyncService` в `HomeShell`: синхронизация при старте, каждые 30 с и при возврате приложения на передний план, если смещение ≥ 50 м). Если координат нет, `users-service` возвращает **пустой список**.

**Сценарий 1 — глобальная лента (`MatchesScreen`).**

1. `GET /api/users/me` — текущий пользователь и его интересы.
2. `UserService.getOtherUsers()` → `**GET /api/users/matches*`* с query-параметрами:
  - `limit = 20` (дефолт и на клиенте, и на сервере);
  - `latitude`, `longitude` — из профиля;
  - `radiusKm = 50` (дефолт).
3. `**users-service`** (`UserService.getMatches` → `UserRepository.findMatches`) сначала собирает пул кандидатов (до `min(limit×4, 80)`), затем ранжирует и возвращает top-`limit`. SQL-фильтры:
  - `id <> текущий пользователь`;
  - `isOnboardingCompleted = true`, `isProfileVisible = true`, `showInMatches = true`;
  - инкогнито (`incognitoMode = true`) скрыт, **кроме** тех, кто уже поставил текущему пользователю `LIKE` (подзапрос к `public."Match"`);
  - кандидат должен иметь `lastLatitude`/`lastLongitude` в **географическом bounding box** вокруг точки запроса (приближение радиуса `radiusKm` в градусах широты/долготы; **не** `ST_Distance` PostGIS);
  - нет записи в `users."UserBlock"` ни в одну сторону;
  - **исключены** пользователи с уже зафиксированным глобальным действием (`LIKE`/`DISLIKE`/`SUPER_LIKE`) или `isMutual = true` в `public."Match"` (без `eventId`);
  - если у текущего пользователя заданы `minAge` / `maxAge` (экран «Приватность» в `EditProfileScreen`) — возраст кандидата должен попадать в диапазон.
   **Скоринг на сервере** (веса в `MatchRecommendationScorer`): `+1000` входящий лайк; `+80` за каждое общее событие со статусом `GOING` (запрос к `events."Participant"`); `+120` за общий интерес; `−3` за км расстояния; `+15` аватар / `+5` bio; штрафы за неполный профиль (`−60` пустой, `−25` без фото, `−20` без интересов, `−10` без bio). Возрастной фильтр настраивается в «Приватность» (`minAge`/`maxAge` → `PUT /api/users/me`).
4. **Клиентская постобработка** (`MatchesScreen._loadMatches`):
  - параллельно `GET /api/matches` — список взаимных мэтчей;
  - из кандидатов убираются: сам пользователь, `mutualIds`, ID из `MatchSeenService` (локальный `SharedPreferences`, ключ `seen_match_user_ids:{userId}`);
  - дедупликация по `id`;
  - **порядок ранжирования с сервера сохраняется** (`preserveServerMatchOrder` в `match_feed_utils.dart`) — клиент не пересортировывает глобальную ленту повторно;
  - каждый `UserModel` → `MatchPreview.fromUserModel` с расчётом **процента совпадения** (Jaccard по множествам интересов: `|A∩B|/|A∪B|`, масштаб 50–100 %) и до трёх общих интересов для подписи на карточке.
5. **Пустая лента.** Если после фильтров список пуст — экран «Нет новых знакомств» с кнопкой «Обновить подборку» (`_refreshMatches(resetSeen: true)` сбрасывает `MatchSeenService` и повторяет шаги 2–4).

**Сценарий 2 — лента в контексте события (`EventMatchScreen`).**

Открывается с `RealEventDetailScreen` (кнопка знакомств у события). Endpoint `/users/matches` **не вызывается**.

1. `GET /api/events/{eventId}` — проверка, что событие не завершено (`actualEndDateTime`);
2. `GET /api/events/{eventId}/participants` — участники;
3. остаются только `status = GOING`, кроме текущего пользователя;
4. для каждого участника — `GET /api/users/{id}` (профиль);
5. тот же клиентский фильтр `MatchSeenService`, сортировка `MatchRecommendationUtils.sortUsers` с учётом `GET /api/matches/incoming-likes?eventId=…` и буста за общее событие (если текущий пользователь тоже `GOING` — каждому кандидату `sharedCount = 1`), затем конвертация в `MatchPreview`;
6. гео- и возрастные фильтры **не применяются** — кандидаты определяются фактом участия в событии.

**Верификация.** Логика ранжирования покрыта unit- и integration-тестами: `MatchRecommendationScorerTest`, `MatchRecommendationIntegrationTest` (Java), `match_recommendation_utils_test.dart`, `match_feed_utils_test.dart` (Flutter).

**Локальный кэш просмотров.** `MatchSeenService` по-прежнему скрывает карточки в текущей сессии до «Обновить подборку», но основной источник истины для уже оценённых профилей — таблица `Match` на сервере. Взаимные мэтчи из глобальной колоды исключаются и на сервере, и на клиенте; отдельно показываются во вкладке «Взаимные» (`GET /api/matches`).

На рисунке 3.10 представлена DFD-схема формирования ленты рекомендаций.

Рисунок 3.10 – DFD «Формирование ленты рекомендаций матчинга» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.10)*

3.2.10 Расчёт ключевых метрик

Ключевые показатели **не хранятся отдельными денormalized-полями** — они вычисляются при чтении профиля, карточки события или формировании ленты. Источники расчёта различаются по домену.

**Метрики событий (`events-service`).**

*Число участников (`participantsCount`).* В геопоиске (`listNearbyApprovedEvents`) — `COUNT(p.id)` по `events."Participant"` в одном SQL-запросе с `GROUP BY e.id`. В карточке одного события (`GET /api/events/{id}`) — отдельный `countParticipants` или поле `_count.participants` в JSON. На клиенте значение попадает в `EventModel.participantsCount` и отображается на карте, в ленте и на `RealEventDetailScreen`.

*Расстояние до события.* Только для **офлайн-событий** в радиусном поиске карты: PostGIS `ST_Distance` / `ST_DWithin` по полю `locationGeo` (тип `geography`, SRID 4326), результат в метрах. Клиент передаёт центр viewport и `maxDistance`; сортировка nearby-выборки — по возрастанию distance. В общей ленте (`listAllApproved` без координат) расстояние на сервере не считается; при необходимости сортировка «по близости» выполняется на клиенте от текущих координат `Geolocator`.

*Рейтинг события.* Таблица `events."EventRating"`: `GET /api/events/{id}/rating/stats` (`RatingRepository.findStats`) возвращает средний балл, число оценок и оценку текущего пользователя.

*Актуальность события.* В nearby-запросе отсекаются записи с `COALESCE(endDateTime, dateTime + 3 hours) <= NOW()`. На клиенте дополнительно проверяется `actualEndDateTime` перед участием и матчингом по событию.

**Метрики организатора (`users-service` + `events-service`).**

При `GET /api/users/me` и `GET /api/users/{id}` репозиторий `findByIdWithRating` выполняет LEFT JOIN к `events."Event"` (только `status = APPROVED`) и `events."EventRating"`. Поле `eventsCreatedCount` — число одобренных событий автора; `averageRating` — средний рейтинг по его событиям **только если** создано ≥ 3 одобренных мероприятий, иначе `null` (рейтинг организатора скрыт).

**Метрики матчинга (`users-service`, `match-service`, клиент).**

*Расстояние между пользователями* в ранжировании ленты — **не PostGIS**: haversine по `lastLatitude`/`lastLongitude` в `MatchRecommendationScorer` (штраф −3 балла за км). Географический **отбор** кандидатов — bounding box в SQL, без `ST_Distance`.

*Взаимные совпадения* — не COUNT-поле в профиле, а записи `public."Match"` с `isMutual = true`; список отдаёт `GET /api/matches`. Число мэтчей на UI — длина этого списка.

*Процент совпадения на карточке* (`MatchPreview`) — Jaccard по множествам интересов на клиенте, не серверная метрика.

На рисунке 3.11 представлена DFD-схема расчёта ключевых метрик.

Рисунок 3.11 – DFD «Расчёт ключевых метрик» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.11)*

3.2.11 Просмотр активности через профиль

Вкладка **«Профиль»** (`ProfileScreen`, index 3 в `HomeShell`) — сводный экран активности пользователя. При открытии `ProfileBloc` выполняет параллельную загрузку:

`GET /api/users/me` — текущий профиль (имя, фото, bio, интересы, рейтинг организатора);

`GET /api/events/user/{userId}` — созданные пользователем события (`status = APPROVED`);

`GET /api/events/user/{userId}/participated` — события с участием, разбивка на «Пойду» (`GOING`) и «Интересно» (`INTERESTED`).

**Блоки интерфейса.** Шапка с аватаром, обложкой и кнопками «Редактировать» / «Приватность»; при активных `UserSanction` — баннер ограничений (`getMySanctions`). Ниже — горизонтальные списки созданных и посещаемых событий (переход на `RealEventDetailScreen` / `EditEventScreen`). Раздел **«Знакомства»** — горизонтальные фильтры-чипы и список карточек `MatchCard`.

**Фильтры симпатий** (`enum _ProfileMatchFilter`):


| Вкладка       | API                                          | Смысл                                   |
| ------------- | -------------------------------------------- | --------------------------------------- |
| Взаимные      | `GET /api/matches`                           | `isMutual = true`                       |
| Меня лайкнули | `GET /api/matches/incoming-likes`            | входящий like/super-like без взаимности |
| Лайкнул       | `GET /api/matches/actions?action=LIKE`       | исходящие лайки                         |
| Пропустил     | `GET /api/matches/actions?action=DISLIKE`    | исходящие дизлайки                      |
| Отложил       | `GET /api/matches/actions?action=SUPER_LIKE` | super-like («подумаю»)                  |


При переключении фильтра данные подгружаются лениво (`_loadMatchesFor`). Пользователи из «Взаимных» исключаются из остальных вкладок, чтобы не дублироваться. Для взаимных и входящих лайков на карточке доступны чувствительные поля профиля (`canViewSensitiveInfo`).

Стартовый список взаимных мэтчей может прийти из `HomeShell._loadMutualMatches` (тот же `GET /api/matches`).

**Редактирование.** `EditProfileScreen` — изменение имени, bio, интересов, медиа через `ProfileBloc` и upload API. Полный экран приватности с `minAge`/`maxAge` открывается из редактирования профиля.

**Ролевой доступ.** Если `user.role` — `MODERATOR` или `ADMIN`, отображается кнопка перехода в `AdminDashboardScreen`. При санкции `FULL_BAN` `HomeShell` принудительно удерживает пользователя на этой вкладке.

На рисунке 3.12 представлена Use-Case диаграмма просмотра активности в профиле.

Рисунок 3.12 – Use-Case «Просмотр активности в профиле» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.12)*

3.2.12 Модерация событий и обработка жалоб

Модерация — **постмодерация** уже опубликованных событий (`APPROVED`). Точка входа: `AdminDashboardScreen` → «Модерация» → `EventModerationScreen` (роли `MODERATOR`, `ADMIN`; проверка на backend через `ModerationAccessService`).

**Загрузка очереди.** Параллельно:

`GET /api/events/moderation/all?limit=500` — все события для модераторского просмотра (включая скрытые санкциями);

`GET /api/users/reports/events` (через `ReportService.getEventReports`) — жалобы с привязкой к `targetEventId`.

Клиент группирует жалобы по событию, считает `pendingReports` (статус `PENDING`) и сортирует: сначала больше pending, затем по дате события. Панель `EventModerationToolbar` — текстовый поиск и фильтр «только с pending».

**Действия модератора.**

*Удалить событие* — `DELETE /api/events/{id}` (`_rejectEvent`): контент снимается с публикации постфактум.

*Закрыть жалобы* — `PUT /api/users/reports/{id}` с телом `{ "resolution": "DISMISSED" | "RESOLVED" }` (отклонить или закрыть жалобу) или массово для всех pending по событию.

*Просмотр жалоб* — bottom sheet `ModerationReportsBottomSheet` с деталями каждого `Report`.

*Санкции на событие* — `EventSanctionsSheet` + `EventSanctionService`: типы `HIDE_VISIBILITY`, `FREEZE_PARTICIPATION`, ограничение редактирования; активные санкции учитываются в публичной выборке (`NOT EXISTS` в `listNearbyApprovedEvents`).

**Модерация пользователей (только ADMIN).** `UsersListScreen` — список пользователей, жалобы на профиль, назначение `UserSanction` (`WARNING`, `MUTE`, `EVENT_CREATE_BAN`, `FULL_BAN`). Санкции блокируют создание событий и отдельные действия в клиенте (`HomeShell._refreshCreateEventAccess`).

На рисунке 3.13 представлена Use-Case диаграмма модерации.

Рисунок 3.13 – Use-Case «Модерация и жалобы» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.13)*

3.2.13 Управление настройками приватности

Экран `**PrivacySettingsScreen`** управляет параметрами видимости и фильтра рекомендаций. Полная версия (включая возраст) открывается из `**EditProfileScreen`**; из `ProfileScreen` доступны только булевы переключатели без `minAge`/`maxAge`.

**Поля UI → API (`PUT /api/users/me`):**


| Параметр                      | Назначение                                              |
| ----------------------------- | ------------------------------------------------------- |
| `showInMatches`               | участие в глобальной ленте знакомств                    |
| `incognitoMode`               | скрытие из чужих лент, кроме тех, кто уже поставил like |
| `showVisitedEvents`           | показ посещённых событий в профиле                      |
| `hideOnlineStatus`            | скрытие статуса «онлайн»                                |
| `minAge` / `maxAge`           | возрастной фильтр кандидатов в `GET /api/users/matches` |
| `clearMinAge` / `clearMaxAge` | сброс диапазона («Любой»)                               |


На backend в `UserRepository.findMatches` дополнительно всегда проверяются `isProfileVisible = true` и `isOnboardingCompleted = true` (поле `isProfileVisible` не выводится в UI, но задаётся при создании пользователя). Возраст кандидата сравнивается с `minAge`/`maxAge` текущего пользователя в SQL.

На рисунке 3.14 представлена Use-Case диаграмма управления приватностью.

Рисунок 3.14 – Use-Case «Настройки приватности» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.14)*

3.2.14 Отправка push-уведомлений

Push реализован **частично**: регистрация токена на клиенте и серверная отправка при **одностороннем** like/super-like; уведомление о **взаимном** мэтче и напоминания о событиях — в планах.

**Клиент (`main.dart`).** После инициализации Firebase вызывается `_configurePushNotifications`: запрос разрешений, `FirebaseMessaging.getToken()`, синхронизация через `UserService.updateFcmToken` → `PUT /api/users/me` с полем `fcmToken`. Повторная синхронизация — при `onTokenRefresh` и при смене `authStateChanges`. Фоновый handler `_firebaseMessagingBackgroundHandler` зарегистрирован; сообщения в foreground только логируются (`onMessage`), отдельный UI локальных уведомлений не подключён.

**Сервер (`match-service`).** При `POST /api/matches/like|super-like`, если действие like-типа и `**isMutual` ещё false**, сервис `CreateOrUpdateMatch` вызывает `NotifyIncomingLike`: читает `fcmToken` получателя из `users."User"`, отправляет push через Firebase Admin SDK (`shared/pkg/firebase`, метод `SendPushNotification`). Тексты: «New like» / «New super like» с `data.type = incoming_like|incoming_super_like`. Пустой или отсутствующий токен — отправка пропускается без ошибки для клиента.

**Не реализовано в текущей версии:** push обоим пользователям при `isMutual = true`; инвалидация устаревших токенов при ошибке FCM; deep link при tap на уведомление. Взаимные мэтчи пользователь видит во вкладке «Взаимные» профиля и через `HomeShell._loadMutualMatches`.

На рисунке 3.15 представлена DFD-схема процесса отправки push-уведомлений.

Рисунок 3.15 – DFD «Push-уведомления (реализованный сценарий)» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.15)*

3.2.15 Просмотр сводной статистики администратором

Административный контур сосредоточен в `**AdminDashboardScreen`** (доступ из профиля модератора/администратора; на web — через `AdminWebAccessGateScreen`). Это не отдельный «дашборд метрик», а **набор инструментов управления** с агрегированными списками и фильтрами.

**Сетка разделов (`AdminDashboardScreen`):**


| Раздел       | Роль       | Экран                   | Назначение                                          |
| ------------ | ---------- | ----------------------- | --------------------------------------------------- |
| Модерация    | MOD, ADMIN | `EventModerationScreen` | события + pending-жалобы, удаление, санкции         |
| Пользователи | ADMIN      | `UsersListScreen`       | роли, жалобы на пользователей, `UserSanction`       |
| Отчёты       | MOD, ADMIN | `ReportsScreen`         | все жалобы, фильтр по статусу, resolve              |
| Аудит        | ADMIN      | `AdminAuditLogsScreen`  | `GET /api/users/admin/audit-logs` — журнал действий |


**Сводные показатели на UI.** `EventModerationScreen` и `ReportsScreen` показывают счётчики отфильтрованных записей (`filteredCount` / `totalCount`, число pending по событию). `ReportsScreen` группирует жалобы по статусам (`PENDING`, `RESOLVED`, `DISMISSED`) через вкладки фильтра. Детальная аналитика (графики, KPI платформы) в приложении не реализована — модератор работает с операционными очередями.

**Типовой сценарий администратора:** открыть «Отчёты» → отфильтровать `PENDING` → перейти в «Модерацию» по событию с наибольшим числом жалоб → удалить контент или назначить `EventSanction` / закрыть жалобы → при необходимости в «Пользователи» наложить `FULL_BAN` на нарушителя → действие фиксируется в «Аудит».

На рисунке 3.16 представлена Use-Case диаграмма работы администратора.

Рисунок 3.16 – Use-Case «Работа администратора» *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.16)*

3.3 Передача и хранение данных

Подсистема передачи и хранения данных связывает Flutter-клиент, API-шлюз Traefik, пять микросервисов и два типа хранилищ — PostgreSQL 16 + PostGIS и MinIO. Все компоненты в dev-окружении поднимаются через `docker-compose.yml` в единой сети `andexevents-network`.

**Общая схема.** Мобильное приложение обращается к одному базовому URL (`AppConfig.baseUrl`, по умолчанию `http://localhost/api` или `--dart-define=API_BASE_URL=...` для физического устройства). Traefik на порту 80 маршрутизирует префиксы:


| Префикс                   | Сервис                         | Порт |
| ------------------------- | ------------------------------ | ---- |
| `/api/users`              | `users-service` (Java/Spring)  | 8081 |
| `/api/events`             | `events-service` (Java/Spring) | 8082 |
| `/api/auth`               | `auth-service` (Java/Spring)   | 8083 |
| `/api/matches`            | `match-service` (Go/Gin)       | 8005 |
| `/api/upload`, `/uploads` | `upload-service` (Go/Gin)      | 8006 |


Защищённые запросы несут заголовок `Authorization: Bearer <Firebase ID Token>`. Каждый сервис самостоятельно верифицирует JWT по JWKS Firebase, извлекает `firebaseUid` и сопоставляет его с `users."User"` (колонки `firebaseUid` / `supabaseUid`). Ответы Java-сервисов — JSON `{ "success": boolean, "data": T, "message": string | null }` (`ApiResponse`).

**Хранилища.**

*PostgreSQL* — одна БД `andexevents`, логически разделённая на схемы `users`, `events`, `public` (таблица `Match`). Миграции Flyway выполняются **независимо** каждым Java-сервисом при старте (`users-service` → schema `users`, `events-service` → schema `events`). Таблица `public."Match"` создаётся init-скриптом `deployments/docker/postgres-init/01-match-table.sql` при первом запуске Postgres.

*MinIO* — S3-совместимое объектное хранилище; buckets `avatars`, `photos`, `events` (инициализация `minio-init`). Метаданные профиля и событий — в PostgreSQL; бинарные файлы — только в MinIO.

*Redis* — поднят в compose, в текущей бизнес-логике сервисов **не используется** (зарезервирован для масштабирования).

Ключевые свойства реализации:

единая физическая БД, несколько логических схем; cross-schema JOIN допустим (например, `users-service` читает `events."Participant"` для ранжирования матчинга);

PostGIS `geography(Point, 4326)` — только для **событий** (`events."Event".locationGeo`, запросы `ST_DWithin`/`ST_Distance`); координаты пользователей — `DOUBLE PRECISION lastLatitude/lastLongitude` + bounding box в SQL;

медиа: upload → MinIO → публичный URL `/uploads/{bucket}/{firebaseUid}/{filename}`; для `avatars`/`photos` upload-service дополнительно пишет в `users."User"`;

локальный кэш на клиенте: `SharedPreferences` (первая страница ленты событий, `MatchSeenService`), без серверного Redis.

3.3.1 Потоки передачи данных

Ниже — как данные проходят через систему по основным сценариям. Формат: **инициатор → HTTP → сервис → хранилище → ответ клиенту**.

**Аутентификация и сессия.**

1. Клиент: Firebase Auth (`LoginScreen` / `RegisterScreen`) → ID Token.
2. `AuthBloc` → `GET /api/users/me` с Bearer Token.
3. `users-service`: `AuthFilter` верифицирует JWT → `UserLookupRepository` находит/создаёт запись в `users."User"`.
4. Ответ: профиль с `isOnboardingCompleted`, `role`, координатами, настройками приватности.
5. Параллельно `main.dart` синхронизирует FCM-токен → `PUT /api/users/me` (`fcmToken`).

**Обновление координат.**

1. `LocationSyncService` (в `HomeShell`) → `PUT /api/users/me/location` `{ latitude, longitude }`.
2. Throttle: первый запуск, смещение ≥ 50 м или интервал 30 с; при `paused`/`hidden` поток останавливается.
3. `users-service` → UPDATE `users."User"` (`lastLatitude`, `lastLongitude`, `lastLocationUpdate`).
4. Координаты используются в `GET /api/users/matches`; на карте событий клиент берёт позицию напрямую из `Geolocator`.

**Карта событий (viewport).**

1. `YandexMapWidget.getVisibleRegion()` → `map_viewport_utils`: центр + радиус (буфер 25 %, min 1500 м).
2. `EventBloc` → `GET /api/events?latitude=&longitude=&maxDistance=&limit=80`.
3. `events-service`: PostGIS `ST_DWithin` по `locationGeo`, фильтр `status=APPROVED`, без `HIDE_VISIBILITY`, `endDateTime > NOW()`; JOIN `Participant` для `participantCount`; `ST_Distance` для сортировки.
4. Клиент **мерджит** новые события (`mergeWithExisting: true`), маркеры фильтрует по текущему viewport.

**Лента событий.**

1. `EventsLoadRequested()` без координат → `GET /api/events?page=1&limit=20`.
2. `events-service.listAllApproved` — все одобренные офлайн-события; первая страница кэшируется в `SharedPreferences`.
3. Фильтры (город, дата, категория, цена, текст) — **на клиенте**; сортировка по рейтингу / участникам / дате.

**Публикация события.**

1. Фото: `POST /api/upload?bucket=events` (multipart `file`) → MinIO bucket `events` → JSON `{ success, fileUrl }`.
2. `POST /api/events` с JSON (title, coordinates, `imageUrl`, `imageUrls`, …).
3. `events-service`: INSERT в `events."Event"` с `locationGeo = ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography`, `**status = APPROVED`** сразу.
4. Событие доступно в ленте и на карте без очереди модерации.

**Участие в событии.**

1. `POST /api/events/{id}/participate` `{ "status": "INTERESTED"|"GOING" }` или `DELETE` для отмены.
2. Проверки: APPROVED, нет бана/санкции/блока организатора; при лимите `maxParticipants` и `GOING` — `WaitlistEntry`.
3. UPSERT в `events."Participant"` (уникальность `userId`+`eventId`).

**Лента матчинга.**

1. `GET /api/users/matches?limit=20&latitude=&longitude=&radiusKm=50`.
2. `users-service`: SQL-фильтры (онбординг, приватность, блокировки, bounding box, minAge/maxAge, исключение уже оценённых в `public."Match"`) → пул → `MatchRecommendationScorer` → top-N.
3. Клиент: исключение mutual + `MatchSeenService` → `preserveServerMatchOrder` → `MatchPreview`.

**Свайп.**

1. `POST /api/matches/like|dislike|super-like` `{ targetUserId, eventId? }`.
2. `match-service`: UPSERT `public."Match"` (`userAAction`/`userBAction`); при двух like-типах — `isMutual=true`, `matchedAt`.
3. При одностороннем like — `NotifyIncomingLike` → FCM (если `fcmToken` задан).
4. Клиент: `MatchSeenService.markSeen` локально.

**Загрузка медиа профиля.**

1. `ImageUtils.compressImage` → `POST /api/upload?bucket=avatars|photos`.
2. MinIO: объект `{firebaseUid}/{timestamp-random}.ext`.
3. `avatars` → UPDATE `photoUrl`; `photos` → `array_append(photos, url)` в PostgreSQL.
4. Клиент может дублировать `photoUrl` через `PUT /api/users/me`; удаление доп. фото — `DELETE /api/upload?bucket=photos&url=...`.

**Модерация и жалобы.**

1. Пользователь: `POST /api/users/reports` → `users."Report"` (`PENDING`).
2. Модератор: `GET /api/events/moderation/all`, `GET /api/users/reports/events`.
3. Действия: `DELETE /api/events/{id}`, `PUT /api/users/reports/{id}` `{ resolution }`, санкции → `events."EventSanction"` / `users."UserSanction"`.
4. ADMIN: `GET /api/users/admin/audit-logs` → `users."AdminAuditLog"`.

Сводная таблица потоков — таблица 3.1.

Таблица 3.1 – Потоки передачи данных


| Процесс          | HTTP / механизм                     | Запись в хранилище                     | Ответ клиенту                |
| ---------------- | ----------------------------------- | -------------------------------------- | ---------------------------- |
| Аутентификация   | Bearer → JWKS → `/users/me`         | чтение/создание `users.User`           | профиль, маршрут онбординга  |
| FCM-токен        | `PUT /users/me`                     | `User.fcmToken`                        | обновлённый профиль          |
| Геолокация       | `PUT /users/me/location`            | `lastLatitude`, `lastLongitude`        | 200 OK                       |
| Карта            | `GET /events` + lat/lon/maxDistance | PostGIS SELECT + COUNT Participant     | JSON events + distance       |
| Лента            | `GET /events?page&limit`            | SELECT APPROVED                        | JSON + клиентский кэш        |
| Создание события | upload events + `POST /events`      | MinIO + INSERT Event APPROVED          | EventDto                     |
| Участие          | `POST/DELETE .../participate`       | UPSERT Participant / Waitlist          | статус участия               |
| Матчинг-лента    | `GET /users/matches`                | SELECT User + JOIN Participant + Match | ранжированный список UserDto |
| Свайп            | `POST /matches/like                 | dislike                                | super-like`                  |
| Медиа            | `POST /upload?bucket=`              | MinIO + UPDATE User (avatars/photos)   | fileUrl                      |
| Жалоба           | `POST /users/reports`               | INSERT Report                          | id жалобы                    |
| Модерация        | DELETE event, PUT report, санкции   | EventSanction, UserSanction, AuditLog  | 200 / обновлённые списки     |


3.3.2 Логическая модель данных

На рисунке 3.17 представлена ER-модель по миграциям Flyway и init-скриптам.

Рисунок 3.17 – Логическая модель базы данных *(см. `[3chapter_diploma_diagrams.md](3chapter_diploma_diagrams.md)`, рис. 3.17 и табл. 3.2)*

**Принцип разделения.** Каждая схема обслуживается своим сервисом, но SQL-запросы могут читать соседние схемы read-only (матчинг читает `users` и `events`; upload пишет в `users`).

**Схема `users`** (миграции V1–V8, Flyway `default-schema: users`).

*User* — центральная сущность. Ключевые группы полей:

идентификация: `id` (TEXT PK), `firebaseUid`, `email`, `role` (enum USER/MODERATOR/ADMIN);

профиль: `displayName`, `photoUrl`, `coverImageUrl`, `photos[]`, `bio`, `interests[]`, `age`, `gender`;

гео: `lastLatitude`, `lastLongitude`, `lastLocationUpdate` (без PostGIS-типа);

приватность: `isProfileVisible`, `isLocationVisible`, `showInMatches`, `incognitoMode`, `showVisitedEvents`, `hideOnlineStatus`, `minAge`, `maxAge`, `maxDistance`;

сессия: `fcmToken`, `isOnboardingCompleted`, `createdAt`, `updatedAt`.

*Report* — жалобы (`reporterId`, `targetUserId?`, `targetEventId?`, `reason`, `status` PENDING/RESOLVED/DISMISSED).

*UserBlock* — блокировка между пользователями (уникальная пара `blockerId`+`targetUserId`); учитывается в `findMatches`.

*UserSanction* — санкции аккаунта (WARNING, MUTE, EVENT_CREATE_BAN, FULL_BAN) с `expiresAt`/`revokedAt`.

*AdminAuditLog* — журнал действий администратора (`actorUserId`, `action`, `details` JSONB).

**Схема `events*`* (миграции V1–V6, Flyway `default-schema: events`).

*Event* — `latitude`/`longitude` (числа) + `**locationGeo`** (PostGIS geography); `status` (PENDING/APPROVED/REJECTED, при создании — APPROVED); `imageUrl`, `imageUrls[]`, `maxParticipants`, `minAge`/`maxAge` события, `createdById`.

*Participant* — связь user↔event, enum INTERESTED/GOING; уникальный индекс `(userId, eventId)`.

*EventRating* — оценка 1–5 и комментарий; UNIQUE `(userId, eventId)`.

*EventSanction* — HIDE_VISIBILITY, FREEZE_PARTICIPATION и др.; фильтруются в публичных SELECT.

*EventParticipantBan*, *OrganizerBlock*, *WaitlistEntry*, *ParticipantCheckIn* — управление участниками (см. §3.2.6).

**Схема `public`.**

*Match* — `userAId`, `userBId`, опциональный `eventId`, `userAAction`/`userBAction` (LIKE/DISLIKE/SUPER_LIKE), `isMutual`, `matchedAt`. Уникальность пары в разрезе события: индекс `(LEAST(userAId,userBId), GREATEST(...), COALESCE(eventId,''))`. FK на `users."User"` ON DELETE CASCADE.

**Объектное хранилище (вне PostgreSQL).**


| Bucket    | Путь объекта           | Связь с БД                                   |
| --------- | ---------------------- | -------------------------------------------- |
| `avatars` | `{firebaseUid}/{file}` | UPDATE `User.photoUrl`                       |
| `photos`  | `{firebaseUid}/{file}` | `array_append(User.photos)`                  |
| `events`  | `{firebaseUid}/{file}` | URL только в JSON события при `POST /events` |


Публичная раздача: Traefik → `upload-service` `GET /uploads/{bucket}/{userId}/{filename}`.

Описание таблиц — таблица 3.2.

Таблица 3.2 – Логическая модель базы данных


| **Таблица**         | **Схема** | **Ключи**                                                                        | **Назначение и основные связи**                                                                                                                                |
| ------------------- | --------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                | users     | id (PK); firebaseUid, supabaseUid, email (UNIQUE)                                | Профиль, координаты (`lastLatitude`/`lastLongitude`), приватность, `fcmToken`, роль. 1:M → Event (`createdById`); 1:M → Participant; 1:M → Match; 1:M → Report |
| Report              | users     | id (PK); reporterId (FK → User); targetUserId (FK → User); targetEventId         | Жалоба на пользователя или событие. Статус PENDING / RESOLVED / DISMISSED. M:1 → User (автор жалобы)                                                           |
| UserBlock           | users     | id (PK); UNIQUE (blockerId, targetUserId); FK → User (обе стороны)               | Блокировка между пользователями. Учитывается при `GET /users/matches`. M:1 → User                                                                              |
| UserSanction        | users     | id (PK); targetUserId (FK → User); createdByUserId (FK → User)                   | Санкции аккаунта: WARNING, MUTE, EVENT_CREATE_BAN, FULL_BAN. M:1 → User (цель)                                                                                 |
| AdminAuditLog       | users     | id (PK); actorUserId (FK → User); targetUserId (FK → User)                       | Журнал действий администратора (`action`, `details` JSONB). M:1 → User                                                                                         |
| Event               | events    | id (PK); createdById (FK → users.User)                                           | Событие: `latitude`/`longitude`, `locationGeo` (PostGIS geography), `status`, медиа. 1:M → Participant, EventRating, EventSanction, WaitlistEntry              |
| Participant         | events    | id (PK); UNIQUE (userId, eventId)                                                | Участие INTERESTED / GOING. M:1 → User; M:1 → Event                                                                                                            |
| EventRating         | events    | id (PK); UNIQUE (userId, eventId); eventId (FK → Event)                          | Оценка события 1–5 и комментарий. M:1 → Event                                                                                                                  |
| EventSanction       | events    | id (PK); eventId (FK → Event)                                                    | Санкции на событие (HIDE_VISIBILITY, FREEZE_PARTICIPATION и др.). Фильтруются в публичной выборке. M:1 → Event                                                 |
| EventParticipantBan | events    | id (PK); UNIQUE (eventId, userId); eventId (FK → Event)                          | Запрет участия конкретного пользователя на событии. M:1 → Event                                                                                                |
| WaitlistEntry       | events    | id (PK); UNIQUE (eventId, userId); eventId (FK → Event)                          | Лист ожидания при переполнении `maxParticipants`. Статус PENDING / APPROVED / REJECTED. M:1 → Event                                                            |
| ParticipantCheckIn  | events    | PK (eventId, userId); eventId (FK → Event)                                       | Отметка чек-ина участника организатором. M:1 → Event                                                                                                           |
| OrganizerBlock      | events    | id (PK); UNIQUE (organizerUserId, blockedUserId)                                 | Блок-лист организатора; блокирует участие в его событиях. Связь логическая с User                                                                              |
| Match               | public    | id (PK); userAId, userBId (FK → users.User); UNIQUE (пара userA/userB + eventId) | Действия LIKE / DISLIKE / SUPER_LIKE, флаг `isMutual`, опциональный `eventId`. M:1 → User (оба участника)                                                      |


3.4 Серверная часть

Серверная часть — ядро платформы Andex Events: верификация Firebase JWT, профили и геолокация, геопоиск событий, участие и модерация, свайпы и загрузка медиа. Реализована как **пять микросервисов** за API-шлюзом **Traefik** (Docker Compose, `docker-compose.yml`). Все сервисы подключаются к одной PostgreSQL 16 + PostGIS; Go-сервисы additionally используют MinIO (upload) и Firebase Admin SDK (match push).

**Состав серверной части.**

| Сервис | Стек | Порт | Префикс Traefik | Ответственность |
| --- | --- | --- | --- | --- |
| `users-service` | Java 21, Spring Boot 3.3.5, Flyway | 8081 | `/api/users` | CRUD профиля, `PUT /me/location`, **`GET /matches`** (ранжирование), жалобы, санкции, аудит |
| `events-service` | Java 21, Spring Boot 3.3.5, Flyway | 8082 | `/api/events` | CRUD событий, PostGIS-поиск, участие, рейтинги, санкции на событие, waitlist, чек-ин |
| `auth-service` | Java 21, Spring Boot 3.3.5 | 8083 | `/api/auth` | Вспомогательная проверка токена: `GET /me`, `POST /validate` |
| `match-service` | Go 1.24, Gin, pgx | 8005 | `/api/matches` | Свайпы, `isMutual`, входящие лайки, **FCM** при одностороннем like |
| `upload-service` | Go 1.24, Gin, MinIO SDK | 8006 | `/api/upload`, `/uploads` | Multipart → MinIO; UPDATE `users.User` для avatars/photos |

**Аутентификация на сервере.** Основной поток: клиент → Traefik → целевой сервис → `AuthFilter` / Go-middleware → верификация JWT по JWKS Firebase → lookup `users."User"` по `firebaseUid`. Отдельный `auth-service` **не проксирует** все запросы — он нужен для диагностики и валидации токена. RBAC: `ModerationAccessService` / проверки роли в контроллерах (`USER`, `MODERATOR`, `ADMIN`).

**Миграции.** `users-service` — Flyway, schema `users` (V1–V8). `events-service` — Flyway, schema `events` (V1–V6). Таблица `public."Match"` — init-скрипт Postgres. Секреты (Firebase SA, MinIO keys, `FIREBASE_JWKS_URL`) — переменные окружения / `secrets/`, не в git.

**Инфраструктура.** Redis поднят в compose, в текущей бизнес-логике **не задействован**. Health: `GET /health` на каждом сервисе.

3.4.1 Контекстная диаграмма IDEF0

На рисунке 3.18 представлена контекстная диаграмма IDEF0 уровня **A-0** в стандартной нотации: слева — входы (I), сверху — управление (C), справа — выходы (O), снизу — механизмы (M). Центральный блок — **«Управление городскими событиями и знакомствами пользователей (платформа Andex Events)»**.

Рисунок 3.18 – Контекстная диаграмма IDEF0 (A-0) *(см. [`3chapter_diploma_diagrams.md`](3chapter_diploma_diagrams.md), рис. 3.18 и табл. 3.3a)*

**Входы (I):**

I1 — HTTP-запросы мобильного клиента (REST, Bearer Token): профиль, события, участие, свайпы, жалобы;

I2 — параметры геопоиска и фильтрации: `latitude`, `longitude`, `radiusKm`, `maxDistance`, `limit`, `minAge`/`maxAge`;

I3 — multipart-медиафайлы и JSON-данные профилей, событий и действий матчинга.

**Управление (C):**

C1 — ролевая модель USER / MODERATOR / ADMIN и политики RBAC;

C2 — настройки приватности (`showInMatches`, `incognitoMode`, `isProfileVisible`, возрастной фильтр);

C3 — правила постмодерации, обработки жалоб (`Report`) и санкций (`UserSanction`, `EventSanction`);

C4 — схемы миграций Flyway и политика хранения данных (Single Database, Multiple Schemas).

**Выходы (O):**

O1 — ответы REST API в формате `{ success, data, message }`;

O2 — ленты событий, ранжированные карточки матчинга, записи `Participant`;

O3 — публичные URL медиафайлов (`/uploads/{bucket}/…`);

O4 — push FCM при входящем like/super-like; статусы `Match` (`isMutual`).

**Механизмы (M):**

M1 — микросервисная архитектура (`users-service`, `events-service`, `auth-service`, `match-service`, `upload-service`);

M2 — PostgreSQL 16 + PostGIS, объектное хранилище MinIO;

M3 — внешние сервисы Firebase Authentication (JWKS) и Firebase Cloud Messaging;

M4 — Docker Compose, API-шлюз Traefik.

3.4.2 Декомпозиция IDEF0

На рисунке 3.19 представлена декомпозиция A-0 на **шесть подпроцессов** A1–A6 в нотации IDEF0 (у каждого блока — вход I, управление C, выход O, механизм M). Цепочка отражает логическую обработку запроса от API-шлюза до формирования ответа клиенту.

Рисунок 3.19 – Декомпозиция IDEF0 (уровень A0) *(см. [`3chapter_diploma_diagrams.md`](3chapter_diploma_diagrams.md), рис. 3.19 и табл. 3.3)*

**A1 — Принятие и маршрутизация HTTP-запросов.** Traefik принимает запрос и по `PathPrefix` направляет его в `users-service`, `events-service`, `auth-service`, `match-service` или `upload-service`.

**A2 — Аутентификация и авторизация.** Целевой сервис верифицирует Firebase JWT, извлекает `firebaseUid`, сопоставляет с `users."User"` и формирует контекст с ролью для RBAC.

**A3 — Управление пользователями и лентой матчинга.** `users-service` обрабатывает профиль, геолокацию и **`GET /users/matches`**: SQL-фильтры + `MatchRecommendationScorer`.

**A4 — Управление событиями и участием.** `events-service` создаёт/ищет события (PostGIS), фиксирует `Participant`, waitlist, рейтинги; учитывает санкции на событие.

**A5 — Обработка свайпов и уведомлений.** `match-service` записывает `LIKE`/`DISLIKE`/`SUPER_LIKE`, выставляет `isMutual`, при одностороннем like отправляет FCM.

**A6 — Загрузка медиа, формирование ответа и аудит.** `upload-service` сохраняет файлы в MinIO и обновляет профиль; все сервисы возвращают `ApiResponse`; действия ADMIN пишутся в `AdminAuditLog`.

Сводная таблица I/C/O/M — **таблица 3.3**.

3.5 Пользовательская часть

Клиент — **Flutter** (Dart SDK ^3.9.2), единая кодовая база iOS / Android. Состояние UI — **BLoC**: `AuthBloc` (сессия и маршрутизация), два независимых `EventBloc` (карта и лента), `ProfileBloc` (профиль). HTTP — пакет `http` через сервисы `UserService`, `EventService`, `ReportService`, `LocalStorageService` (upload). Базовый URL — `AppConfig.baseUrl` (`http://localhost/api`, эмулятор Android `10.0.2.2`, override `--dart-define=API_BASE_URL=http://<IP>/api`). Карты — **Yandex MapKit** (`YandexMapWidget`, ключ `--dart-define=YANDEX_MAPS_API_KEY=...`).

3.5.1 Интерфейс приложения

Главный контейнер — **`HomeShell`**: `IndexedStack` из четырёх вкладок + **`HomeFloatingNavBar`** (центральная кнопка «+»). **Подписи вкладок в UI:** «Карта», «Афиша», «Матчи», «Профиль».

| Index | Подпись в UI | Экран | BLoC / особенности |
| --- | --- | --- | --- |
| 0 | Карта | `MapExploreScreen` | `_mapEventBloc`; viewport-загрузка, debounce 350 мс, merge событий |
| 1 | Афиша | `EventsFeedScreen` | `_feedEventBloc`; заголовок «Афиша города»; кэш 1-й страницы, клиентские фильтры |
| 2 | Матчи | `MatchesScreen` | `MatchSwipeDeck`; `/users/matches` + `MatchSeenService` |
| 3 | Профиль | `ProfileScreen` | `ProfileBloc`; мероприятия, матчи, «Панель модератора» / «Панель администратора» |

**Навбар «+»** → `CreateEventScreen` (кнопка «Создать событие»). При `EVENT_CREATE_BAN` — SnackBar «Создание событий ограничено»; при `FULL_BAN` — только вкладка «Профиль», сообщение «Доступ ограничен: при FULL_BAN доступен только профиль».

**Стартовая навигация:** `AndexApp` → `AuthBloc` → при отсутствии сессии карусель `OnboardingScreen` (3 слайда, «Далее»/«Начать», «Пропустить») → `LoginScreen` / `RegisterScreen` / `ForgotPasswordScreen` → при `!emailVerified` `EmailVerificationScreen` → онбординг `SetupProfileScreen` → `SetupInterestsScreen` → `SetupLocationScreen` → `HomeShell`. На `RealEventDetailScreen`: сердечко (INTERESTED), «Участвовать» (GOING), «Метчи» → `EventMatchScreen`. Выход — «Выйти из аккаунта» в `EditProfileScreen`. При старте `HomeShell` — `LocationSyncService`, `_loadMutualMatches`.

Рисунок 3.21 – Поток навигации клиентского приложения *(см. [`3chapter_diploma_diagrams.md`](3chapter_diploma_diagrams.md), рис. 3.21)*

3.5.2 Потоки работы пользователя

Полный текст §3.5.2–3.7 в академическом стиле вынесен в [`3chapter_diploma_353_37.md`](3chapter_diploma_353_37.md): для каждого сценария — вводный абзац, блок «Действия пользователя», блок «Результат действий пользователя».

**Содержание §3.5.2:** 3.5.2.1 авторизация → 3.5.2.9 админ-панель (9 пользовательских сценариев).

3.5.3 Основные экраны и их функции

Полный текст §3.5.2–3.7 в академическом стиле вынесен в [`3chapter_diploma_353_37.md`](3chapter_diploma_353_37.md).