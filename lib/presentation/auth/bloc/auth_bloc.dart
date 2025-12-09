import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../data/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

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

    // Подписываемся на изменения состояния авторизации Supabase
    _authStateSubscription = _authService.authStateChanges.listen((supabase.AuthState state) {
      // Supabase AuthState содержит event и session.
      // Нас интересует факт изменения сессии или события входа/выхода.
      // Просто триггерим проверку.
      add(const AuthCheckRequested());
    });
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final supabase.User? user = _authService.currentUser;
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
    emit(const AuthLoading());
    try {
      final supabase.AuthResponse response = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      if (response.user == null) {
        throw Exception('Ошибка входа: пользователь не найден');
      }

      // Загружаем профиль для проверки onboarding
      try {
        final userProfile = await _authService.getCurrentUserProfile();
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        emit(AuthAuthenticated(
          user: response.user!,
          isOnboardingCompleted: isOnboardingCompleted,
        ));
      } catch (e) {
        // Если не удалось загрузить профиль, считаем что onboarding не завершен
        emit(AuthAuthenticated(
          user: response.user!,
          isOnboardingCompleted: false,
        ));
      }
    } catch (e) {
      print('🔴 [AuthBloc] Login error: $e');
      emit(AuthFailure(message: e.toString()));
      // emit(const AuthUnauthenticated());
    }
  }

  /// Регистрация через Email и пароль
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    print('🔵 [AuthBloc] Регистрация началась');
    emit(const AuthLoading());
    try {
      final supabase.AuthResponse response = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      if (response.user == null) {
        throw Exception('Ошибка регистрации: пользователь не создан');
      }

      print('🔵 [AuthBloc] Регистрация успешна');
      print('🔵 [AuthBloc] User ID: ${response.user!.id}');
      print('🔵 [AuthBloc] Session: ${response.session != null}');
      if (response.session?.accessToken != null) {
        print('🔵 [AuthBloc] Access Token: ${response.session!.accessToken.substring(0, 20)}...');
      }
      
      // Проверяем, есть ли активная сессия
      if (response.session == null) {
        print('🟡 [AuthBloc] Сессия отсутствует - требуется подтверждение email');
        throw Exception(
          'Для завершения регистрации необходимо подтвердить email. '
          'Проверьте почту и перейдите по ссылке из письма.'
        );
      }
      
      // Даём время на полную инициализацию сессии в Supabase client
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('🔵 [AuthBloc] Эмитим AuthAuthenticated с isOnboardingCompleted: false');
      // После регистрации пользователь должен пройти онбординг
      emit(AuthAuthenticated(
        user: response.user!,
        isOnboardingCompleted: false,
      ));
      print('🔵 [AuthBloc] AuthAuthenticated эмитен');
    } catch (e) {
      print('🔴 [AuthBloc] Register error: $e');
      emit(AuthFailure(message: e.toString()));
      // emit(const AuthUnauthenticated());
    }
  }

  /// Вход через Google
  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    print('🔵 [AuthBloc] Google Sign-In requested');
    emit(const AuthLoading());
    try {
      print('🔵 [AuthBloc] Вызываем authService.signInWithGoogleAndGetStatus()');
      final result = await _authService.signInWithGoogleAndGetStatus();
      
      final supabase.AuthResponse response = result['userCredential'] as supabase.AuthResponse;
      final bool isOnboardingCompleted = result['isOnboardingCompleted'] as bool;
      
      if (response.user == null) {
        throw Exception('Ошибка Google Sign-In: пользователь не найден');
      }

      print('🔵 [AuthBloc] Google Sign-In успешен, isOnboardingCompleted: $isOnboardingCompleted');
      
      emit(AuthAuthenticated(
        user: response.user!,
        isOnboardingCompleted: isOnboardingCompleted,
      ));
    } catch (e) {
      print('🔴 [AuthBloc] Google Sign-In ошибка: $e');
      emit(AuthFailure(message: e.toString()));
      // Не сбрасываем в Unauthenticated сразу, чтобы UI успел показать ошибку
      // emit(const AuthUnauthenticated()); 
    }
  }

  /// Выход из системы
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
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
