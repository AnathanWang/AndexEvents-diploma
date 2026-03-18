import 'package:andexevents/data/services/auth_service.dart';
import 'package:andexevents/presentation/auth/bloc/auth_bloc.dart';
import 'package:andexevents/presentation/auth/bloc/auth_state.dart';
import 'package:andexevents/presentation/auth/screens/register_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'register_screen_email_validation_test.mocks.dart';

@GenerateMocks([AuthService, AuthBloc])
void main() {
  late MockAuthService mockAuthService;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthBloc = MockAuthBloc();

    // Default BLoC setup
    when(mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
    when(mockAuthBloc.state).thenReturn(const AuthInitial());
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: RegisterScreen(authService: mockAuthService),
      ),
    );
  }

  group('RegisterScreen - Email Availability Validation', () {
    testWidgets('should show checking indicator when validating email', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability(any))
          .thenAnswer((_) => Future.delayed(const Duration(milliseconds: 100), () => true));

      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 500)); // Debounce time
      
      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Clean up - wait for async operations to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should show available status when email is free', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability('test@example.com'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 600)); // Wait for debounce
      await tester.pumpAndSettle(); // Wait for async operation

      // Assert
      expect(find.textContaining('Доступен'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should show taken status when email is already registered', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability('taken@example.com'))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'taken@example.com');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Занят'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('should disable register button when email is taken', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability('taken@example.com'))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(createWidgetUnderTest());

      // Fill in required fields
      await tester.enterText(find.byKey(const Key('register_name_textField')), 'Test User');
      await tester.enterText(find.byKey(const Key('register_email_textField')), 'taken@example.com');
      await tester.enterText(find.byKey(const Key('register_password_textField')), 'Password123');
      await tester.enterText(find.byKey(const Key('register_confirmPassword_textField')), 'Password123');
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Act & Assert
      final registerButton = find.byKey(const Key('register_button'));
      expect(tester.widget<ElevatedButton>(registerButton).enabled, isFalse);
    });

    testWidgets('should not call API on every keystroke (debounce)', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability(any))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());

      // Act - type email character by character
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 't');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(emailField, 'te');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - API should not be called yet (debounce not elapsed)
      verifyNever(mockAuthService.checkEmailAvailability(any));

      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Now API should be called once
      verify(mockAuthService.checkEmailAvailability('test@example.com')).called(1);
    });

    testWidgets('should not validate email when format is invalid', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability(any))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());

      // Act - enter invalid email
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'invalid-email');
      await tester.pump(const Duration(milliseconds: 600));

      // Assert - API should not be called for invalid format
      verifyNever(mockAuthService.checkEmailAvailability(any));
      
      // Verify no availability status is shown (should be initial)
      expect(find.textContaining('Доступен'), findsNothing);
      expect(find.textContaining('Занят'), findsNothing);
      expect(find.textContaining('Проверка'), findsNothing);
    });

    testWidgets('should handle API errors gracefully', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability(any))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Assert - should show error message
      expect(find.textContaining('Ошибка проверки'), findsOneWidget);
    });

    testWidgets('should clear previous status when email changes', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.checkEmailAvailability('test1@example.com'))
          .thenAnswer((_) async => true);
      when(mockAuthService.checkEmailAvailability('test2@example.com'))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(createWidgetUnderTest());

      // Act - First email (available)
      final emailField = find.byKey(const Key('register_email_textField'));
      await tester.enterText(emailField, 'test1@example.com');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.textContaining('Доступен'), findsOneWidget);

      // Act - Change email (taken)
      await tester.enterText(emailField, 'test2@example.com');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Assert - should show new status
      expect(find.textContaining('Занят'), findsOneWidget);
      expect(find.textContaining('Доступен'), findsNothing);
    });
  });
}
