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
  final String? photoUrl;
  final String? coverImageUrl;
  final List<String>? photos;
  final String? bio;
  final List<String>? interests;
  final Map<String, String>? socialLinks;
  final bool? showVisitedEvents;
  final bool? showInMatches;
  final bool? incognitoMode;
  final bool? hideOnlineStatus;

  const ProfileUpdateRequested({
    this.displayName,
    this.photoUrl,
    this.coverImageUrl,
    this.photos,
    this.bio,
    this.interests,
    this.socialLinks,
    this.showVisitedEvents,
    this.showInMatches,
    this.incognitoMode,
    this.hideOnlineStatus,
  });

  @override
  List<Object?> get props => [
    displayName,
    photoUrl,
    coverImageUrl,
    photos,
    bio,
    interests,
    socialLinks,
    showVisitedEvents,
    showInMatches,
    incognitoMode,
    hideOnlineStatus,
  ];
}

/// Обновить фото профиля
class ProfilePhotoUpdateRequested extends ProfileEvent {
  final String photoPath;

  const ProfilePhotoUpdateRequested(this.photoPath);

  @override
  List<Object?> get props => [photoPath];
}

/// Загрузить дополнительное фото профиля
class AdditionalPhotoUploadRequested extends ProfileEvent {
  final String photoPath;

  const AdditionalPhotoUploadRequested(this.photoPath);

  @override
  List<Object?> get props => [photoPath];
}

/// Удалить дополнительное фото профиля
class AdditionalPhotoDeleteRequested extends ProfileEvent {
  final String photoUrl;

  const AdditionalPhotoDeleteRequested(this.photoUrl);

  @override
  List<Object?> get props => [photoUrl];
}
