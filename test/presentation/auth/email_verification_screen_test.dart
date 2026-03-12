import 'dart:async';

import 'package:andexevents/data/services/auth_service.dart';
import 'package:andexevents/presentation/auth/screens/email_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'email_verification_screen_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget createTestWidget({String? userEmail}) {
    return MaterialApp(
      home: EmailVerificationScreen(
        userEmail: userEmail ?? 'test@example.com',
        authService: mockAuthService,
      ),
    );
  }

  group('EmailVerificationScreen Widget Tests', () {
    testWidgets('displays user email and verification message',
        (WidgetTester tester) async {
      // Arrange
      const testEmail = 'user@example.com';

      // Act
      await tester.pumpWidget(createTestWidget(userEmail: testEmail));

      // Assert
      expect(find.text('Проверьте почту'), findsOneWidget);
      expect(find.textContaining(testEmail), findsOneWidget);
      expect(
        find.text('Мы отправили письмо с подтверждением на указанный адрес'),
        findsOneWidget,
      );
    });

    testWidgets('displays resend button', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(
        find.widgetWithText(ElevatedButton, 'Отправить письмо повторно'),
        findsOneWidget,
      );
    });

    testWidgets('resend button calls sendVerificationEmail when pressed',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());

      // Act
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuthService.sendVerificationEmail()).called(1);
    });

    testWidgets('shows loading indicator during resend',
        (WidgetTester tester) async {
      // Arrange
      final completer = Completer<void>();
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());

      // Act
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the operation
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows success message after successful resend',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());

      // Act
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Письмо отправлено'), findsOneWidget);
    });

    testWidgets('shows error message when resend fails',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenThrow(Exception('network-request-failed'));

      await tester.pumpWidget(createTestWidget());

      // Act
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Ошибка'), findsOneWidget);
    });

    testWidgets('disables resend button during cooldown period',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());

      // Act - first resend
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Assert - button should be disabled
      final buttonWidget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('shows cooldown timer after resend',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());

      // Act
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Assert - should show remaining seconds
      expect(find.textContaining('сек'), findsOneWidget);
    });

    testWidgets('re-enables button after cooldown expires',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.sendVerificationEmail())
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());

      // Act - first resend
      final resendButton = find.widgetWithText(
        ElevatedButton,
        'Отправить письмо повторно',
      );
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      // Wait for cooldown (simulate 60 seconds)
      await tester.pump(const Duration(seconds: 61));

      // Assert - button should be enabled again
      final buttonWidget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('has back button to navigate to login',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Вернуться к входу'), findsOneWidget);
    });

    testWidgets('navigates back when back button pressed',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailVerificationScreen(
                        userEmail: 'test@example.com',
                        authService: mockAuthService,
                      ),
                    ),
                  );
                },
                child: const Text('Go to Verification'),
              ),
            ),
          ),
        ),
      );

      // Act - navigate to verification screen
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);

      // Act - tap back button
      final backButton = find.text('Вернуться к входу');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Assert - should navigate back
      expect(find.byType(EmailVerificationScreen), findsNothing);
    });
  });
}
