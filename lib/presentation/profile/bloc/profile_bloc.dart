import '../../../data/models/event_model.dart';

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
    final previousUser = switch (state) {
      ProfileLoaded(:final user) => user,
      ProfileUpdating(:final user) => user,
      ProfileError(:final user?) => user,
      _ => null,
    };

    emit(const ProfileLoading());

    try {
      final fetchedUser = await _userService.getCurrentUser();
      final shouldKeepPreviousCover =
          (fetchedUser.coverImageUrl == null ||
              fetchedUser.coverImageUrl!.trim().isEmpty) &&
          previousUser?.coverImageUrl != null &&
          previousUser!.coverImageUrl!.trim().isNotEmpty;

      final user = shouldKeepPreviousCover
          ? fetchedUser.copyWith(coverImageUrl: previousUser.coverImageUrl)
          : fetchedUser;

      final results = await Future.wait<List<EventModel>>([
        _eventService.getUserEvents(user.id),
        _eventService.getUserParticipatedEvents(user.id),
      ]);

      final userEvents = results[0];
      final participated = results[1];

      final going = <EventModel>[];
      final interested = <EventModel>[];
      for (final ev in participated) {
        if (ev.userParticipationStatus == 'GOING') {
          going.add(ev);
        } else if (ev.userParticipationStatus == 'INTERESTED') {
          interested.add(ev);
        } else {
          going.add(ev);
        }
      }

      emit(
        ProfileLoaded(
          user,
          userEvents: userEvents,
          goingEvents: going,
          interestedEvents: interested,
        ),
      );
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
      ProfileUpdating(
        currentState.user,
        userEvents: currentState.userEvents,
        goingEvents: currentState.goingEvents,
        interestedEvents: currentState.interestedEvents,
      ),
    );

    try {
      await _userService.updateProfile(
        displayName: event.displayName,
        photoUrl: event.photoUrl,
        coverImageUrl: event.coverImageUrl,
        photos: event.photos,
        bio: event.bio,
        interests: event.interests,
        socialLinks: event.socialLinks,
        showVisitedEvents: event.showVisitedEvents,
        showInMatches: event.showInMatches,
        incognitoMode: event.incognitoMode,
        hideOnlineStatus: event.hideOnlineStatus,
      );

      // Перезагружаем профиль
      final fetchedUser = await _userService.getCurrentUser();
      final hasReturnedCover =
          fetchedUser.coverImageUrl != null &&
          fetchedUser.coverImageUrl!.trim().isNotEmpty;
      final shouldUseRequestedCover =
          event.coverImageUrl != null &&
          event.coverImageUrl!.trim().isNotEmpty &&
          !hasReturnedCover;

      final updatedUser = shouldUseRequestedCover
          ? fetchedUser.copyWith(coverImageUrl: event.coverImageUrl)
          : fetchedUser;

      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      final res = await Future.wait([
        _eventService.getUserParticipatedEvents(updatedUser.id),
      ]);
      final g = <EventModel>[];
      final i = <EventModel>[];
      for (var ev in res[0]) {
        if (ev.userParticipationStatus == 'GOING') {
          g.add(ev);
        } else if (ev.userParticipationStatus == 'INTERESTED') {
          i.add(ev);
        } else {
          g.add(ev);
        }
      }
      emit(
        ProfileLoaded(
          updatedUser,
          userEvents: userEvents,
          goingEvents: g,
          interestedEvents: i,
        ),
      );
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
      ProfileUpdating(
        currentState.user,
        userEvents: currentState.userEvents,
        goingEvents: currentState.goingEvents,
        interestedEvents: currentState.interestedEvents,
      ),
    );

    try {
      // Загружаем фото
      LoggerService.debug('🔵 [ProfileBloc] Начинаем загрузку фото...');
      final photoUrl = await _userService.uploadProfilePhoto(
        File(event.photoPath),
      );

      // Обновляем профиль с новым URL фото
      LoggerService.debug(
        '🔵 [ProfileBloc] Обновляем профиль с photoUrl: $photoUrl',
      );
      await _userService.updateProfile(photoUrl: photoUrl);

      // Перезагружаем профиль
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info('🟢 [ProfileBloc] Фото обновлено успешно');
      final res = await Future.wait([
        _eventService.getUserParticipatedEvents(updatedUser.id),
      ]);
      final g = <EventModel>[];
      final i = <EventModel>[];
      for (var ev in res[0]) {
        if (ev.userParticipationStatus == 'GOING') {
          g.add(ev);
        } else if (ev.userParticipationStatus == 'INTERESTED') {
          i.add(ev);
        } else {
          g.add(ev);
        }
      }
      emit(
        ProfileLoaded(
          updatedUser,
          userEvents: userEvents,
          goingEvents: g,
          interestedEvents: i,
        ),
      );
    } catch (e) {
      LoggerService.error('🔴 [ProfileBloc] Ошибка обновления фото: $e');
      LoggerService.warning(
        '⚠️ [ProfileBloc] Это может быть проблема VPN или симулятора iOS',
      );

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
      ProfileUpdating(
        currentState.user,
        userEvents: currentState.userEvents,
        goingEvents: currentState.goingEvents,
        interestedEvents: currentState.interestedEvents,
      ),
    );

    try {
      LoggerService.debug(
        '🔵 [ProfileBloc] Начинаем загрузку дополнительного фото...',
      );
      final photoUrl = await _userService.uploadAdditionalPhoto(
        File(event.photoPath),
      );

      LoggerService.debug(
        '🔵 [ProfileBloc] Добавляем фото в профиль: $photoUrl',
      );
      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info(
        '🟢 [ProfileBloc] Дополнительное фото загружено успешно',
      );
      final res = await Future.wait([
        _eventService.getUserParticipatedEvents(updatedUser.id),
      ]);
      final g = <EventModel>[];
      final i = <EventModel>[];
      for (var ev in res[0]) {
        if (ev.userParticipationStatus == 'GOING') {
          g.add(ev);
        } else if (ev.userParticipationStatus == 'INTERESTED') {
          i.add(ev);
        } else {
          g.add(ev);
        }
      }
      emit(
        ProfileLoaded(
          updatedUser,
          userEvents: userEvents,
          goingEvents: g,
          interestedEvents: i,
        ),
      );
    } catch (e) {
      LoggerService.error(
        '🔴 [ProfileBloc] Ошибка загрузки дополнительного фото: $e',
      );
      emit(
        ProfileError('Не удалось загрузить фото: $e', user: currentState.user),
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
      ProfileUpdating(
        currentState.user,
        userEvents: currentState.userEvents,
        goingEvents: currentState.goingEvents,
        interestedEvents: currentState.interestedEvents,
      ),
    );

    try {
      LoggerService.debug('🔵 [ProfileBloc] Удаляем фото: ${event.photoUrl}');
      await _userService.deleteAdditionalPhoto(event.photoUrl);

      final updatedUser = await _userService.getCurrentUser();
      final userEvents = await _eventService.getUserEvents(updatedUser.id);
      LoggerService.info('🟢 [ProfileBloc] Фото удалено успешно');
      final res = await Future.wait([
        _eventService.getUserParticipatedEvents(updatedUser.id),
      ]);
      final g = <EventModel>[];
      final i = <EventModel>[];
      for (var ev in res[0]) {
        if (ev.userParticipationStatus == 'GOING') {
          g.add(ev);
        } else if (ev.userParticipationStatus == 'INTERESTED') {
          i.add(ev);
        } else {
          g.add(ev);
        }
      }
      emit(
        ProfileLoaded(
          updatedUser,
          userEvents: userEvents,
          goingEvents: g,
          interestedEvents: i,
        ),
      );
    } catch (e) {
      LoggerService.error('🔴 [ProfileBloc] Ошибка удаления фото: $e');
      emit(
        ProfileError('Не удалось удалить фото: $e', user: currentState.user),
      );
    }
  }
}
