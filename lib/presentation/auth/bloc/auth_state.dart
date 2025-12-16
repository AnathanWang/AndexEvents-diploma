import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Состояния для AuthBloc
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние (проверяем авторизацию)
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Загрузка (вход, регистрация, выход)
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Пользователь авторизован
class AuthAuthenticated extends AuthState {
  final User user;
  final bool isOnboardingCompleted;

  const AuthAuthenticated({
    required this.user,
    this.isOnboardingCompleted = false,
  });

  @override
  List<Object?> get props => [user, isOnboardingCompleted];
}

/// Пользователь не авторизован
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Ошибка авторизации
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Успешный сброс пароля
class AuthPasswordResetSuccess extends AuthState {
  const AuthPasswordResetSuccess();
}
