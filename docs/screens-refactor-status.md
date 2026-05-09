# Статус рефакторинга экранов (glass UI)

Цель: светло-голубой glassmorphism, токены `AppColors`, карточки с радиусом 24, единые состояния loading / error / empty где применимо.

Общий фон сцены (градиент + круги): виджет [`GlassSceneStack`](../lib/presentation/widgets/glass_scene_stack.dart) — используется в [`AuthGlassScaffold`](../lib/presentation/auth/widgets/auth_glass_scaffold.dart), детальном экране события, каркасе домашних вкладок и экране выбора точки на карте.

Старый список в [`NOT_REFACTORED_SCREENS.md`](../NOT_REFACTORED_SCREENS.md) **устарел**.

---

## Готово или приведено к целевому стилю

| Область | Экран / модуль |
|--------|----------------|
| **Онбординг** | `OnboardingScreen` |
| **Auth** | `LoginScreen`, `RegisterScreen`, `ForgotPasswordScreen`, `EmailVerificationScreen`, `SetupProfileScreen`, `SetupInterestsScreen`, `SetupLocationScreen` |
| **Home** | `EventsFeedScreen`, `MapExploreScreen`, `MatchesScreen`, `ProfileScreen`, `SearchScreen`, **`HomeShell`** (фон `GlassSceneStack` под вкладками и нижней навигацией) |
| **События** | `CreateEventScreen`, `EditEventScreen`, `EventDetailScreen`, **`RealEventDetailScreen`** (общий фон, `AuthGlassScaffold` для loading/error), **`MapLocationPicker`** (`AuthGlassScaffold`, нижняя панель — `AuthGlassCard`) |
| **Мэтчи** | `EventMatchScreen` |
| **Профиль** | `EditProfileScreen`, `UserProfileScreen`, `PrivacySettingsScreen` |
| **Админ / модер** | `AdminWebAccessGateScreen`, `AdminDashboardScreen`, `EventModerationScreen`, `ReportsScreen`, `UsersListScreen`, `AdminAuditLogsScreen` (+ общие виджеты и вынесенные блоки) |

---

## Частично или отложено

На данный момент отдельных экранов в этой секции нет. Углублённая полировка секций внутри `RealEventDetailScreen` (отдельные карточки/шиты) возможна по желанию, но базовый glass-каркас и состояния загрузки/ошибки унифицированы.

---

## Прочее (не классы `*Screen`)

- Web-вход админки: `main_admin_web.dart`, `andex_admin_web_app.dart`.
- Диалоги и bottom sheets — точечно в том же визуальном ключе при правках.

---

## Как обновлять этот файл

После рефактора: добавить или переместить строку в таблицу «Готово». При новых экранах в `lib/presentation` — дополнить список.
