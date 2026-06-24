import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:andexevents/presentation/auth/bloc/auth_bloc.dart';
import 'package:andexevents/presentation/auth/bloc/auth_event.dart';
import 'package:andexevents/presentation/auth/bloc/auth_state.dart';

@GenerateMocks([AuthService, User, UserMetadata])
import 'auth_bloc_session_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockUser mockUser;
  late MockUserMetadata mockMetadata;
  late StreamController<User?> authStateController;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
    mockMetadata = MockUserMetadata();
    authStateController = StreamController<User?>.broadcast();

    when(mockUser.uid).thenReturn('uid-1');
    when(mockUser.email).thenReturn('user@example.com');
    when(mockUser.emailVerified).thenReturn(true);
    when(mockUser.metadata).thenReturn(mockMetadata);
    when(mockMetadata.creationTime).thenReturn(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    when(mockAuthService.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
    when(mockAuthService.currentUser).thenReturn(mockUser);
    when(mockAuthService.hadPreviousSession()).thenAnswer((_) async => false);
    when(mockAuthService.getCachedOnboardingStatus())
        .thenAnswer((_) async => true);
    when(mockAuthService.getCurrentUserProfile()).thenAnswer(
      (_) async => {'isOnboardingCompleted': true},
    );
    when(mockAuthService.markSessionActive(any)).thenAnswer((_) async {});
    when(mockAuthService.cacheOnboardingStatus(any)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authStateController.close();
  });

  AuthBloc buildBloc() => AuthBloc(authService: mockAuthService);

  group('AuthBloc session restore', () {
    blocTest<AuthBloc, AuthState>(
      'restores authenticated state when Firebase user exists',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        isA<AuthAuthenticated>()
            .having((s) => s.isOnboardingCompleted, 'onboarding', true),
      ],
      verify: (_) {
        verify(mockAuthService.markSessionActive('uid-1')).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'shows onboarding immediately when Firebase user is missing',
      build: () {
        when(mockAuthService.currentUser).thenReturn(null);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'waits for Firebase restore when session marker exists',
      build: () {
        var calls = 0;
        when(mockAuthService.currentUser).thenAnswer((_) {
          calls++;
          return calls >= 3 ? mockUser : null;
        });
        when(mockAuthService.hadPreviousSession()).thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      wait: const Duration(seconds: 1),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>()
            .having((s) => s.isOnboardingCompleted, 'onboarding', true),
      ],
    );
  });
}
