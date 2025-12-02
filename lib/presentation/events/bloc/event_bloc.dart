import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/event_service.dart';
import 'event_event.dart';
import 'event_state.dart';

/// BLoC для управления событиями
class EventBloc extends Bloc<EventEvent, EventState> {
  final EventService _eventService;

  EventBloc({EventService? eventService})
      : _eventService = eventService ?? EventService(),
        super(const EventInitial()) {
    on<EventsLoadRequested>(_onEventsLoadRequested);
    on<EventDetailLoadRequested>(_onEventDetailLoadRequested);
    on<EventCreateRequested>(_onEventCreateRequested);
    on<EventPhotoUploadRequested>(_onEventPhotoUploadRequested);
    on<EventParticipateRequested>(_onEventParticipateRequested);
    on<EventCancelParticipationRequested>(_onEventCancelParticipationRequested);
  }

  Future<void> _onEventsLoadRequested(
    EventsLoadRequested event,
    Emitter<EventState> emit,
  ) async {
    if (event.page == 1) {
      emit(const EventsLoading());
    }

    try {
      final events = await _eventService.getEvents(
        category: event.category,
        latitude: event.latitude,
        longitude: event.longitude,
        maxDistance: event.maxDistance,
        page: event.page,
        limit: 20,
      );

      if (state is EventsLoaded && event.page > 1) {
        final currentState = state as EventsLoaded;
        emit(EventsLoaded(
          events: [...currentState.events, ...events],
          hasMore: events.length >= 20,
          currentPage: event.page,
        ));
      } else {
        emit(EventsLoaded(
          events: events,
          hasMore: events.length >= 20,
          currentPage: event.page,
        ));
      }
    } catch (e) {
      emit(EventError('Не удалось загрузить события: $e'));
    }
  }

  Future<void> _onEventDetailLoadRequested(
    EventDetailLoadRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventDetailLoading());

    try {
      final eventModel = await _eventService.getEventById(event.eventId);
      emit(EventDetailLoaded(eventModel));
    } catch (e) {
      emit(EventError('Не удалось загрузить событие: $e'));
    }
  }

  Future<void> _onEventCreateRequested(
    EventCreateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventCreating());

    try {
      final eventModel = await _eventService.createEvent(
        title: event.title,
        description: event.description,
        category: event.category,
        location: event.location,
        latitude: event.latitude,
        longitude: event.longitude,
        dateTime: event.dateTime,
        endDateTime: event.endDateTime,
        price: event.price,
        imageUrl: event.imageUrl,
        isOnline: event.isOnline,
        maxParticipants: event.maxParticipants,
        minAge: event.minAge,
        maxAge: event.maxAge,
      );

      emit(EventCreated(eventModel));
    } catch (e) {
      emit(EventError('Не удалось создать событие: $e'));
    }
  }

  Future<void> _onEventPhotoUploadRequested(
    EventPhotoUploadRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventPhotoUploading());

    try {
      final photoUrl = await _eventService.uploadEventPhoto(File(event.photoPath));
      emit(EventPhotoUploaded(photoUrl));
    } catch (e) {
      emit(EventError('Не удалось загрузить фото: $e'));
    }
  }

  Future<void> _onEventParticipateRequested(
    EventParticipateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventParticipationUpdating());

    try {
      await _eventService.participateInEvent(event.eventId, event.status);
      emit(const EventParticipationUpdated());
    } catch (e) {
      emit(EventError('Не удалось участвовать в событии: $e'));
    }
  }

  Future<void> _onEventCancelParticipationRequested(
    EventCancelParticipationRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventParticipationUpdating());

    try {
      await _eventService.cancelParticipation(event.eventId);
      emit(const EventParticipationUpdated());
    } catch (e) {
      emit(EventError('Не удалось отменить участие: $e'));
    }
  }
}
