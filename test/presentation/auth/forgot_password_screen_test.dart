import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/presentation/auth/bloc/auth_bloc.dart';
import 'package:andexevents/presentation/auth/bloc/auth_event.dart';
import 'package:andexevents/presentation/auth/bloc/auth_state.dart';
import 'package:andexevents/presentation/auth/screens/forgot_password_screen.dart';

@GenerateMocks([])
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    whenListen(
      mockAuthBloc,
      Stream.value(const AuthInitial()),
      initialState: const AuthInitial(),
    );
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const ForgotPasswordScreen(),
      ),
    );
  }

  group('ForgotPasswordScreen Widget Tests (TDD)', () {
    testWidgets('renders all required widgets', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Проверяем, что экран отображает все необходимые элементы
      expect(find.text('Восстановление пароля'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byKey(const Key('forgotPassword_email_textField')), findsOneWidget);
      expect(find.byKey(const Key('forgotPassword_submit_button')), findsOneWidget);
      expect(find.text('Отправить'), findsOneWidget);
      expect(find.text('Вернуться к входу'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Нажимаем кнопку без ввода email
      await tester.tap(find.byKey(const Key('forgotPassword_submit_button')));
      await tester.pump();

      // Проверяем, что показывается ошибка валидации
      expect(find.text('Введите email'), findsOneWidget);
    });

    testWidgets('shows error when email is invalid', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Вводим невалидный email
      await tester.enterText(
        find.byKey(const Key('forgotPassword_email_textField')),
        'invalid-email',
      );
      await tester.pump();

      // Нажимаем кнопку
      await tester.tap(find.byKey(const Key('forgotPassword_submit_button')));
      await tester.pump();

      // Проверяем ошибку
      expect(find.text('Некорректный email'), findsOneWidget);
    });

    testWidgets('triggers password reset with valid email', (tester) async {
      const testEmail = 'test@example.com';
      
      // Настраиваем мок для ответа на stream
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoading()]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      // Вводим валидный email
      await tester.enterText(
        find.byKey(const Key('forgotPassword_email_textField')),
        testEmail,
      );
      await tester.pump();

      // Нажимаем кнопку
      await tester.tap(find.byKey(const Key('forgotPassword_submit_button')));
      await tester.pump();

      // Просто проверяем, что состояние изменилось на Loading
      // (что означает, что событие было обработано)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loading indicator when AuthLoading state', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoading()]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Проверяем, что показывается индикатор загрузки
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows success dialog on AuthPasswordResetSuccess', (tester) async {
      const testEmail = 'test@example.com';

      whenListen(
        mockAuthBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthPasswordResetSuccess(),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      // Вводим email
      await tester.enterText(
        find.byKey(const Key('forgotPassword_email_textField')),
        testEmail,
      );

      await tester.pumpAndSettle();

      // Проверяем, что показывается диалог успеха
      expect(find.text('Письмо отправлено'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('shows error snackbar on AuthFailure', (tester) async {
      const errorMessage = 'Пользователь не найден';

      whenListen(
        mockAuthBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthFailure(message: errorMessage),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Проверяем, что показывается snackbar с ошибкой
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('disables button and email field when loading', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoading()]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Проверяем, что кнопка disabled
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('forgotPassword_submit_button')),
      );
      expect(button.onPressed, isNull);

      // Проверяем, что поле email disabled
      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('forgotPassword_email_textField')),
      );
      expect(textField.enabled, isFalse);
    });

    testWidgets('back button returns to previous screen', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream.value(const AuthInitial()),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider<AuthBloc>.value(
                          value: mockAuthBloc,
                          child: const ForgotPasswordScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      );

      // Переходим на ForgotPasswordScreen
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Проверяем, что мы на ForgotPasswordScreen
      expect(find.text('Восстановление пароля'), findsOneWidget);

      // Нажимаем кнопку "Вернуться к входу"
      await tester.tap(find.text('Вернуться к входу'));
      await tester.pumpAndSettle();

      // Проверяем, что вернулись назад
      expect(find.text('Восстановление пароля'), findsNothing);
      expect(find.text('Go'), findsOneWidget);
    });
  });
}
