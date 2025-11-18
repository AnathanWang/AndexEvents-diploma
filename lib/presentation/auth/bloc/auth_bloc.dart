import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

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

    // Подписываемся на изменения состояния авторизации Firebase
    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
      add(const AuthCheckRequested());
    });
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final User? user = _authService.currentUser;
    if (user != null) {
      // TODO: Проверить isOnboardingCompleted через API
      // Пока просто эмитим как завершённый онбординг
      emit(AuthAuthenticated(user: user, isOnboardingCompleted: true));
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
      final UserCredential credential = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      // TODO: Получить isOnboardingCompleted из backend
      emit(AuthAuthenticated(
        user: credential.user!,
        isOnboardingCompleted: true,
      ));
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
      emit(const AuthUnauthenticated());
    }
  }

  /// Регистрация через Email и пароль
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final UserCredential credential = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      // После регистрации пользователь должен пройти онбординг
      emit(AuthAuthenticated(
        user: credential.user!,
        isOnboardingCompleted: false,
      ));
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
      emit(const AuthUnauthenticated());
    }
  }

  /// Вход через Google
  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final UserCredential credential = await _authService.signInWithGoogle();

      // Если новый пользователь - отправляем на онбординг
      final bool isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      
      emit(AuthAuthenticated(
        user: credential.user!,
        isOnboardingCompleted: !isNewUser,
      ));
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
      emit(const AuthUnauthenticated());
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
      emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
