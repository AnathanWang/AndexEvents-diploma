# Несоответствующие дизайну экраны

В ходе аудита 27 экранов в директории `lib/presentation/` были найдены следующие экраны, которые **не соответствуют** новому UI-дизайну («light blue glassmorphism»). Эти экраны используют старые цвета (например, жесткий серый `#75878A`), плоский белый фон для страниц вместо градиента, и стандартные карточки без "glassmorphism" эффектов.

При рефакторинге следует использовать `AppColors.background` или `AppDecorations.pageGradient`, а также сглаженные карточки с радиусом скругления не менее 16-24 пунктов.

## Административная панель (Admin)
- `lib/presentation/admin/screens/admin_audit_logs_screen.dart`
- `lib/presentation/admin/screens/event_moderation_screen.dart`
- `lib/presentation/admin/screens/reports_screen.dart`
- `lib/presentation/admin/screens/users_list_screen.dart`

*(Примечание: `admin_dashboard_screen.dart` и `admin_web_access_gate_screen.dart` уже используют новые градиенты и формы).*

## Авторизация (Auth)
- `lib/presentation/auth/screens/email_verification_screen.dart`
- `lib/presentation/auth/screens/forgot_password_screen.dart`

*(Примечание: экраны `register_screen.dart`, `login_screen.dart`, и `setup_*` уже были обновлены).*

## Мероприятия (Events)
- `lib/presentation/events/screens/edit_event_screen.dart`
- `lib/presentation/events/screens/event_detail_screen.dart`

*(Примечание: экраны `create_event_screen.dart` и `real_event_detail_screen.dart` соответствуют новому контексту)*.

**Общий итог:** 8 из 27 экранов нуждаются в редизайне.
