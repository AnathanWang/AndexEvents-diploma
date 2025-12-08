import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    emit(ProfileUpdating(currentState.user, userEvents: currentState.userEvents));

    try {
      await _userService.updateProfile(
        displayName: event.displayName,
        bio: event.bio,
        interests: event.interests,
        socialLinks: event.socialLinks,
      );

      // Перезагружаем профиль
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      emit(ProfileError(
        'Не удалось обновить профиль: $e',
        user: currentState.user,
      ));
    }
  }

  Future<void> _onProfilePhotoUpdateRequested(
    ProfilePhotoUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(ProfileUpdating(currentState.user, userEvents: currentState.userEvents));

    try {
      // Загружаем фото
      final photoUrl = await _userService.uploadProfilePhoto(File(event.photoPath));

      // Обновляем профиль с новым URL фото
      await _userService.updateProfile(photoUrl: photoUrl);

      // Перезагружаем профиль
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      emit(ProfileLoaded(updatedUser, userEvents: userEvents));
    } catch (e) {
      emit(ProfileError(
        'Не удалось обновить фото: $e',
        user: currentState.user,
      ));
    }
  }
}
