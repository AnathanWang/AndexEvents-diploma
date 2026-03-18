import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:andexevents/core/auth/id_token_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

@GenerateMocks([FirebaseAuth, GoogleSignIn, IdTokenProvider, UserCredential, User])
import 'auth_service_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockIdTokenProvider mockIdTokenProvider;
  late AuthService authService;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockIdTokenProvider = MockIdTokenProvider();
    
    authService = AuthService(
      auth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
      idTokenProvider: mockIdTokenProvider,
    );
  });

  group('AuthService - Password Reset (TDD)', () {
    const testEmail = 'test@example.com';
    const invalidEmail = 'invalid-email';

    test('resetPassword should call sendPasswordResetEmail with correct email', () async {
      // Arrange
      when(mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenAnswer((_) async => Future.value());

      // Act
      await authService.resetPassword(testEmail);

      // Assert
      verify(mockFirebaseAuth.sendPasswordResetEmail(email: testEmail)).called(1);
    });

    test('resetPassword should complete successfully for valid email', () async {
      // Arrange
      when(mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenAnswer((_) async => Future.value());

      // Act & Assert - should not throw
      expect(authService.resetPassword(testEmail), completes);
    });

    test('resetPassword should throw Exception when FirebaseAuth throws user-not-found', () async {
      // Arrange
      when(mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      // Act & Assert
      expect(
        () => authService.resetPassword(testEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('resetPassword should throw Exception when FirebaseAuth throws invalid-email', () async {
      // Arrange
      when(mockFirebaseAuth.sendPasswordResetEmail(email: invalidEmail))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      // Act & Assert
      expect(
        () => authService.resetPassword(invalidEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('resetPassword should throw Exception when FirebaseAuth throws network error', () async {
      // Arrange
      when(mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      // Act & Assert
      expect(
        () => authService.resetPassword(testEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('resetPassword should handle empty email gracefully', () async {
      // Arrange
      const emptyEmail = '';
      when(mockFirebaseAuth.sendPasswordResetEmail(email: emptyEmail))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      // Act & Assert
      expect(
        () => authService.resetPassword(emptyEmail),
        throwsA(isA<Exception>()),
      );
    });
  });
}
