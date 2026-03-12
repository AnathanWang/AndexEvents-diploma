import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/data/services/auth_service.dart';

import 'auth_service_email_verification_test.mocks.dart';

@GenerateMocks([FirebaseAuth, User], customMocks: [
  MockSpec<UserCredential>(as: #MockUserCredentialForVerification),
])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    authService = AuthService(auth: mockFirebaseAuth);
  });

  group('AuthService - Email Verification', () {
    group('sendVerificationEmail', () {
      test('should call sendEmailVerification on current user', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.email).thenReturn('test@example.com');
        when(mockUser.sendEmailVerification()).thenAnswer((_) async => {});

        // Act
        await authService.sendVerificationEmail();

        // Assert
        verify(mockUser.sendEmailVerification()).called(1);
      });

      test('should throw Exception when no user is logged in', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act & Assert
        expect(
          () => authService.sendVerificationEmail(),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw Exception when sendEmailVerification fails', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.sendEmailVerification())
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        // Act & Assert
        expect(
          () => authService.sendVerificationEmail(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle too-many-requests error', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.sendEmailVerification())
            .thenThrow(FirebaseAuthException(code: 'too-many-requests'));

        // Act & Assert
        expect(
          () => authService.sendVerificationEmail(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('isEmailVerified', () {
      test('should return true when email is verified', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.emailVerified).thenReturn(true);

        // Act
        final result = authService.isEmailVerified;

        // Assert
        expect(result, isTrue);
      });

      test('should return false when email is not verified', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.emailVerified).thenReturn(false);

        // Act
        final result = authService.isEmailVerified;

        // Assert
        expect(result, isFalse);
      });

      test('should return false when no user is logged in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = authService.isEmailVerified;

        // Assert
        expect(result, isFalse);
      });
    });

    group('reloadUser', () {
      test('should call reload on current user', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.reload()).thenAnswer((_) async => {});

        // Act
        await authService.reloadUser();

        // Assert
        verify(mockUser.reload()).called(1);
      });

      test('should throw Exception when no user is logged in', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act & Assert
        expect(
          () => authService.reloadUser(),
          throwsA(isA<Exception>()),
        );
      });

      test('should update emailVerified status after reload', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.reload()).thenAnswer((_) async => {});
        when(mockUser.emailVerified).thenReturn(false);

        // Act
        await authService.reloadUser();
        final verifiedBefore = authService.isEmailVerified;
        
        when(mockUser.emailVerified).thenReturn(true);
        final verifiedAfter = authService.isEmailVerified;

        // Assert
        verify(mockUser.reload()).called(1);
        expect(verifiedBefore, isFalse);
        expect(verifiedAfter, isTrue);
      });
    });
  });
}
