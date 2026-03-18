import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:andexevents/presentation/auth/bloc/auth_bloc.dart';
import 'package:andexevents/presentation/auth/bloc/auth_event.dart';
import 'package:andexevents/presentation/auth/bloc/auth_state.dart';

@GenerateMocks([AuthService])
import 'auth_bloc_password_reset_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late AuthBloc authBloc;

  setUp(() {
    mockAuthService = MockAuthService();
    // Mock authStateChanges stream that AuthBloc listens to
    when(mockAuthService.authStateChanges).thenAnswer((_) => Stream.value(null));
    // Mock currentUser that AuthBloc checks during initialization
    when(mockAuthService.currentUser).thenReturn(null);
    authBloc = AuthBloc(authService: mockAuthService);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc - Password Reset (TDD)', () {
    const testEmail = 'test@example.com';

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthPasswordResetSuccess, AuthUnauthenticated] when password reset succeeds',
      build: () {
        when(mockAuthService.resetPassword(testEmail))
            .thenAnswer((_) async => Future.value());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthPasswordResetRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthPasswordResetSuccess(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(mockAuthService.resetPassword(testEmail)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] when password reset fails with user-not-found',
      build: () {
        when(mockAuthService.resetPassword(testEmail))
            .thenThrow(Exception('Пользователь не найден'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthPasswordResetRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(message: 'Exception: Пользователь не найден'),
      ],
      verify: (_) {
        verify(mockAuthService.resetPassword(testEmail)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] when password reset fails with invalid-email',
      build: () {
        when(mockAuthService.resetPassword('invalid'))
            .thenThrow(Exception('Некорректный email'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthPasswordResetRequested(email: 'invalid')),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(message: 'Exception: Некорректный email'),
      ],
      verify: (_) {
        verify(mockAuthService.resetPassword('invalid')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] when password reset fails with network error',
      build: () {
        when(mockAuthService.resetPassword(testEmail))
            .thenThrow(Exception('Нет подключения к интернету'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthPasswordResetRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(message: 'Exception: Нет подключения к интернету'),
      ],
      verify: (_) {
        verify(mockAuthService.resetPassword(testEmail)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'calls authService.resetPassword exactly once per event',
      build: () {
        when(mockAuthService.resetPassword(testEmail))
            .thenAnswer((_) async => Future.value());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthPasswordResetRequested(email: testEmail)),
      verify: (_) {
        verify(mockAuthService.resetPassword(testEmail)).called(1);
        // Note: Don't use verifyNoMoreInteractions as authStateChanges and currentUser
        // are called during AuthBloc initialization
      },
    );
  });
}
