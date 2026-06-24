import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/services/logger_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  /// Prevents the authStateChanges listener from re-triggering AuthCheckRequested
  /// while a login/register/logout handler is already running.
  bool _handlingAuthAction = false;
  bool _explicitLogout = false;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);

    _authStateSubscription = _authService.authStateChanges.listen((_) {
      if (!_handlingAuthAction) {
        add(const AuthCheckRequested());
      }
    });
  }

  Future<void> _markSession(User user) async {
    await _authService.markSessionActive(user.uid);
  }

  Future<void> _emitAuthenticated(
    Emitter<AuthState> emit,
    User user, {
    required bool isOnboardingCompleted,
  }) async {
    await _markSession(user);
    emit(AuthAuthenticated(
      user: user,
      isOnboardingCompleted: isOnboardingCompleted,
    ));
  }

  Future<User?> _waitForRestoredUser() async {
    const attempts = 15;
    const step = Duration(milliseconds: 200);

    for (var i = 0; i < attempts; i++) {
      final user = _authService.currentUser;
      if (user != null) {
        LoggerService.info(
          '🔵 [AuthBloc] Firebase session restored after ${(i + 1) * step.inMilliseconds}ms',
        );
        return user;
      }
      await Future<void>.delayed(step);
    }
    return _authService.currentUser;
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.info('🔵 [AuthBloc] Проверка начального состояния...');
    User? user = _authService.currentUser;

    if (user == null && await _authService.hadPreviousSession()) {
      LoggerService.info(
        '🔵 [AuthBloc] Маркер сессии есть, ждём восстановление Firebase...',
      );
      emit(const AuthLoading());
      user = await _waitForRestoredUser();
      if (user == null) {
        LoggerService.warning(
          '🟡 [AuthBloc] Firebase не восстановил сессию, очищаем маркер',
        );
        await _authService.clearSessionMarker();
      }
    }

    if (user == null) {
      LoggerService.info('🔵 [AuthBloc] Пользователь не найден, показываем Onboarding');
      emit(const AuthUnauthenticated());
      return;
    }

    _explicitLogout = false;
    LoggerService.info('🔵 [AuthBloc] Пользователь найден в Firebase: ${user.email}');

    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled') {
        LoggerService.error(
          '🔴 [AuthBloc] Пользователь удален или заблокирован в Firebase. Выполняю автоматический выход.',
        );
        await _authService.signOut();
        emit(const AuthUnauthenticated());
        return;
      }
    } catch (_) {
      LoggerService.warning(
        '🟡 [AuthBloc] Не удалось выполнить user.reload(), возможно нет сети.',
      );
    }

    final cachedOnboarding = await _authService.getCachedOnboardingStatus();
    if (cachedOnboarding != null) {
      LoggerService.info('🔵 [AuthBloc] Используем кэш онбординга: $cachedOnboarding');
      await _emitAuthenticated(
        emit,
        user,
        isOnboardingCompleted: cachedOnboarding,
      );
    }

    try {
      LoggerService.info('🔵 [AuthBloc] Загрузка профиля из backend...');
      final userProfile = await _authService
          .getCurrentUserProfile()
          .timeout(const Duration(seconds: 6));
      LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
      final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
      LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
      await _authService.cacheOnboardingStatus(isOnboardingCompleted);
      await _emitAuthenticated(
        emit,
        user,
        isOnboardingCompleted: isOnboardingCompleted,
      );
    } catch (e) {
      if (cachedOnboarding == null) {
        final isNewUser = user.metadata.creationTime != null &&
            DateTime.now().difference(user.metadata.creationTime!) <
                const Duration(hours: 1);
        final fallbackOnboarding = isNewUser ? false : true;

        LoggerService.warning(
          '🟡 [AuthBloc] Профиль не загрузился и кэша нет, fallbackOnboarding=$fallbackOnboarding',
          e,
        );
        await _emitAuthenticated(
          emit,
          user,
          isOnboardingCompleted: fallbackOnboarding,
        );
      } else {
        LoggerService.warning(
          '🟡 [AuthBloc] Не удалось загрузить профиль на старте, продолжаем с кэшем',
          e,
        );
      }
    }
  }

  /// Вход через Email и пароль
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    _explicitLogout = false;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка входа: пользователь не найден');
      }

      try {
        LoggerService.info('🔵 [AuthBloc] Загрузка профиля пользователя...');
        final userProfile = await _authService.getCurrentUserProfile();
        LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
        await _authService.cacheOnboardingStatus(isOnboardingCompleted);
        await _emitAuthenticated(
          emit,
          user,
          isOnboardingCompleted: isOnboardingCompleted,
        );
      } catch (e) {
        final cachedOnboarding = await _authService.getCachedOnboardingStatus();
        LoggerService.error('🔴 [AuthBloc] Ошибка загрузки профиля', e);

        final isNewUser = user.metadata.creationTime != null &&
            DateTime.now().difference(user.metadata.creationTime!) <
                const Duration(hours: 1);

        final fallbackOnboarding = cachedOnboarding ?? (isNewUser ? false : true);
        LoggerService.warning('🟡 [AuthBloc] Используем fallback onboarding=$fallbackOnboarding');

        await _emitAuthenticated(
          emit,
          user,
          isOnboardingCompleted: fallbackOnboarding,
        );
      }
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Login error: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Регистрация через Email и пароль
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Регистрация началась');
    _handlingAuthAction = true;
    _explicitLogout = false;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка регистрации: пользователь не создан');
      }

      await _authService.cacheOnboardingStatus(false);

      await _emitAuthenticated(
        emit,
        user,
        isOnboardingCompleted: false,
      );
      LoggerService.debug('🔵 [AuthBloc] AuthAuthenticated эмитен');
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Register error: $e');
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.cacheOnboardingStatus(false);
        await _emitAuthenticated(
          emit,
          user,
          isOnboardingCompleted: false,
        );
      } else {
        emit(AuthFailure(message: e.toString()));
      }
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Вход через Google
  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Google Sign-In requested');
    _handlingAuthAction = true;
    _explicitLogout = false;
    emit(const AuthLoading());
    try {
      LoggerService.debug('🔵 [AuthBloc] Вызываем authService.signInWithGoogleAndGetStatus()');
      final result = await _authService.signInWithGoogleAndGetStatus();

      final UserCredential response = result['userCredential'] as UserCredential;
      final bool isOnboardingCompleted = result['isOnboardingCompleted'] as bool;

      final user = response.user;
      if (user == null) throw Exception('Ошибка Google Sign-In: пользователь не найден');

      LoggerService.debug('🔵 [AuthBloc] Google Sign-In успешен, isOnboardingCompleted: $isOnboardingCompleted');

      await _emitAuthenticated(
        emit,
        user,
        isOnboardingCompleted: isOnboardingCompleted,
      );
      await _authService.cacheOnboardingStatus(isOnboardingCompleted);
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Google Sign-In ошибка: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Выход из системы
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    _explicitLogout = true;
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Сброс пароля
  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.resetPassword(event.email);
      emit(const AuthPasswordResetSuccess());
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
