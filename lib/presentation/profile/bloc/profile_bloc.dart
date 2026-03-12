import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/services/event_service.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC для управления профилем пользователя
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserService _userService;
  final EventService _eventService;

  ProfileBloc({UserService? userService, EventService? eventService})
    : _userService = userService ?? UserService(),
      _eventService = eventService ?? EventService(),
      super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<ProfileUpdateRequested>(_onProfileUpdateRequested);
    on<ProfilePhotoUpdateRequested>(_onProfilePhotoUpdateRequested);
    on<AdditionalPhotoUploadRequested>(_onAdditionalPhotoUploadRequested);
    on<AdditionalPhotoDeleteRequested>(_onAdditionalPhotoDeleteRequested);
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    try {
      final user = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(user.id);
      emit(ProfileLoaded(user, userEvents: userEvents));
    } catch (e) {
      emit(ProfileError('Не удалось загрузить профиль: $e'));
    }
  }

  Future<void> _onProfileUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(
      ProfileUpdating(currentState.user, userEvents: currentState.userEvents),
    );

    try {
      await _userService.updateProfile(
        displayName: event.displayName,
        photoUrl: event.photoUrl,
        photos: event.photos,
        bio: event.bio,
        interests: event.interests,
        socialLinks: event.socialLinks,
      );

      // Перезагружаем профиль
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      emit(
        ProfileError(
          'Не удалось обновить профиль: $e',
          user: currentState.user,
        ),
      );
    }
  }

  Future<void> _onProfilePhotoUpdateRequested(
    ProfilePhotoUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(
      ProfileUpdating(currentState.user, userEvents: currentState.userEvents),
    );

    try {
      // Загружаем фото
      LoggerService.debug('🔵 [ProfileBloc] Начинаем загрузку фото...');
      final photoUrl = await _userService.uploadProfilePhoto(
        File(event.photoPath),
      );

      // Обновляем профиль с новым URL фото
      LoggerService.debug('🔵 [ProfileBloc] Обновляем профиль с photoUrl: $photoUrl');
      await _userService.updateProfile(photoUrl: photoUrl);

      // Перезагружаем профиль
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info('🟢 [ProfileBloc] Фото обновлено успешно');
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      LoggerService.error('🔴 [ProfileBloc] Ошибка обновления фото: $e');
      LoggerService.warning('⚠️ [ProfileBloc] Это может быть проблема VPN или симулятора iOS');

      // Возвращаемся в ProfileLoaded без ошибки
      emit(
        ProfileError(
          'Не удалось загрузить фото (проблема сети/симулятора). Попробуйте: 1) Отключить VPN 2) Использовать реальное устройство',
          user: currentState.user,
        ),
      );
    }
  }

  Future<void> _onAdditionalPhotoUploadRequested(
    AdditionalPhotoUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(
      ProfileUpdating(currentState.user, userEvents: currentState.userEvents),
    );

    try {
      LoggerService.debug('🔵 [ProfileBloc] Начинаем загрузку дополнительного фото...');
      final photoUrl = await _userService.uploadAdditionalPhoto(
        File(event.photoPath),
      );

      LoggerService.debug('🔵 [ProfileBloc] Добавляем фото в профиль: $photoUrl');
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info('🟢 [ProfileBloc] Дополнительное фото загружено успешно');
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      LoggerService.error('🔴 [ProfileBloc] Ошибка загрузки дополнительного фото: $e');
      emit(
        ProfileError(
          'Не удалось загрузить фото: $e',
          user: currentState.user,
        ),
      );
    }
  }

  Future<void> _onAdditionalPhotoDeleteRequested(
    AdditionalPhotoDeleteRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(
      ProfileUpdating(currentState.user, userEvents: currentState.userEvents),
    );

    try {
      LoggerService.debug('🔵 [ProfileBloc] Удаляем фото: ${event.photoUrl}');
      await _userService.deleteAdditionalPhoto(event.photoUrl);

      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info('🟢 [ProfileBloc] Фото удалено успешно');
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      LoggerService.error('🔴 [ProfileBloc] Ошибка удаления фото: $e');
      emit(
        ProfileError(
          'Не удалось удалить фото: $e',
          user: currentState.user,
        ),
      );
    }
  }
}
