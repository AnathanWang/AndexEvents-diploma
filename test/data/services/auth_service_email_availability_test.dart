import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/data/services/auth_service.dart';

import 'auth_service_email_availability_test.mocks.dart';

@GenerateMocks([FirebaseAuth])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockFirebaseAuth);
  });

  group('AuthService - checkEmailAvailability', () {
    const testEmail = 'test@example.com';

    test('should return true when email is available (empty sign-in methods)', () async {
      // Arrange
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail))
          .thenAnswer((_) async => []);

      // Act
      final result = await authService.checkEmailAvailability(testEmail);

      // Assert
      expect(result, isTrue);
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail)).called(1);
    });

    test('should return false when email is already registered (has sign-in methods)', () async {
      // Arrange
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail))
          .thenAnswer((_) async => ['password']);

      // Act
      final result = await authService.checkEmailAvailability(testEmail);

      // Assert
      expect(result, isFalse);
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail)).called(1);
    });

    test('should return false when email has multiple sign-in methods', () async {
      // Arrange
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail))
          .thenAnswer((_) async => ['password', 'google.com']);

      // Act
      final result = await authService.checkEmailAvailability(testEmail);

      // Assert
      expect(result, isFalse);
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail)).called(1);
    });

    test('should throw Exception when Firebase throws error', () async {
      // Arrange
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      // Act & Assert
      expect(
        () => authService.checkEmailAvailability(testEmail),
        throwsA(isA<Exception>()),
      );
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(testEmail)).called(1);
    });

    test('should throw Exception for invalid email format', () async {
      // Arrange
      const invalidEmail = 'invalid-email';
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(invalidEmail))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      // Act & Assert
      expect(
        () => authService.checkEmailAvailability(invalidEmail),
        throwsA(isA<Exception>()),
      );
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(invalidEmail)).called(1);
    });

    test('should handle empty email gracefully', () async {
      // Arrange
      const emptyEmail = '';
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(emptyEmail))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      // Act & Assert
      expect(
        () => authService.checkEmailAvailability(emptyEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('should trim whitespace from email before checking', () async {
      // Arrange
      const emailWithSpaces = '  test@example.com  ';
      const trimmedEmail = 'test@example.com';
      when(mockFirebaseAuth.fetchSignInMethodsForEmail(trimmedEmail))
          .thenAnswer((_) async => []);

      // Act
      final result = await authService.checkEmailAvailability(emailWithSpaces);

      // Assert
      expect(result, isTrue);
      verify(mockFirebaseAuth.fetchSignInMethodsForEmail(trimmedEmail)).called(1);
    });
  });
}
