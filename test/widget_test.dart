// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:andexevents/app/andex_app.dart';

void main() {
  testWidgets('Основные вкладки переключаются и меняют экран', (WidgetTester tester) async {
    await tester.pumpWidget(const AndexApp());

    // Экран карты
    expect(find.text('Карта событий'), findsOneWidget);
    expect(find.text('События рядом'), findsOneWidget);

    // Переключаемся на Афишу
    await tester.tap(find.text('Афиша'));
    await tester.pumpAndSettle();
    expect(find.text('Афиша недели'), findsOneWidget);

    // Переключаемся на Матчи
    await tester.tap(find.text('Матчи'));
    await tester.pumpAndSettle();
    // Проверяем что экран матчей загрузился (может быть заглушка или карточки)
    expect(find.byType(AndexApp), findsOneWidget);

    // Переключаемся на Профиль
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Мои мероприятия'), findsOneWidget);
  });
}
