import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

/// Состояния для ProfileBloc
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Загрузка профиля
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Профиль загружен
class ProfileLoaded extends ProfileState {
  final UserModel user;

  const ProfileLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

/// Обновление профиля
class ProfileUpdating extends ProfileState {
  final UserModel user;

  const ProfileUpdating(this.user);

  @override
  List<Object?> get props => [user];
}

/// Ошибка
class ProfileError extends ProfileState {
  final String message;
  final UserModel? user;

  const ProfileError(this.message, {this.user});

  @override
  List<Object?> get props => [message, user];
}
