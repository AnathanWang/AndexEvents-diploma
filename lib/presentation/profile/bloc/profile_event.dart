import 'package:equatable/equatable.dart';

/// События для ProfileBloc
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить профиль текущего пользователя
class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

/// Обновить профиль
class ProfileUpdateRequested extends ProfileEvent {
  final String? displayName;
  final String? bio;
  final List<String>? interests;

  const ProfileUpdateRequested({
    this.displayName,
    this.bio,
    this.interests,
  });

  @override
  List<Object?> get props => [displayName, bio, interests];
}

/// Обновить фото профиля
class ProfilePhotoUpdateRequested extends ProfileEvent {
  final String photoPath;

  const ProfilePhotoUpdateRequested(this.photoPath);

  @override
  List<Object?> get props => [photoPath];
}
