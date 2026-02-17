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

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) {
    // Регистрируем обработчики событий
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);

    _authStateSubscription = _authService.authStateChanges.listen((_) {
      // Skip if a login/register/logout handler triggered this change
      if (!_handlingAuthAction) {
        add(const AuthCheckRequested());
      }
    });
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final User? user = _authService.currentUser;
    if (user != null) {
      try {
        // Загружаем профиль из бэкенда для проверки onboarding
        final userProfile = await _authService.getCurrentUserProfile();
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: isOnboardingCompleted));
      } catch (e) {
        // Если не удалось загрузить профиль, считаем что onboarding не завершен
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: false));
      }
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Вход через Email и пароль
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
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

      // Загружаем профиль для проверки onboarding
      try {
        final userProfile = await _authService.getCurrentUserProfile();
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: isOnboardingCompleted,
        ));
      } catch (e) {
        // Если не удалось загрузить профиль, считаем что onboarding не завершен
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: false,
        ));
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

      // После регистрации пользователь должен пройти онбординг
      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: false,
      ));
      LoggerService.debug('🔵 [AuthBloc] AuthAuthenticated эмитен');
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Register error: $e');
      emit(AuthFailure(message: e.toString()));
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
    emit(const AuthLoading());
    try {
      LoggerService.debug('🔵 [AuthBloc] Вызываем authService.signInWithGoogleAndGetStatus()');
      final result = await _authService.signInWithGoogleAndGetStatus();
      
      final UserCredential response = result['userCredential'] as UserCredential;
      final bool isOnboardingCompleted = result['isOnboardingCompleted'] as bool;
      
      final user = response.user;
      if (user == null) throw Exception('Ошибка Google Sign-In: пользователь не найден');

      LoggerService.debug('🔵 [AuthBloc] Google Sign-In успешен, isOnboardingCompleted: $isOnboardingCompleted');
      
      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: isOnboardingCompleted,
      ));
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
      // emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
