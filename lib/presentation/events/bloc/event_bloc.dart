import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/events/event_refresh_bus.dart';
import '../../../core/constants/event_messages.dart';
import '../../../data/models/event_model.dart';
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
    on<EventsMergeListRequested>(_onEventsMergeListRequested);
    on<EventDetailLoadRequested>(_onEventDetailLoadRequested);
    on<EventCreateRequested>(_onEventCreateRequested);
    on<EventPhotoUploadRequested>(_onEventPhotoUploadRequested);
    on<EventParticipateRequested>(_onEventParticipateRequested);
    on<EventCancelParticipationRequested>(_onEventCancelParticipationRequested);
    on<EventParticipantsLoadRequested>(_onEventParticipantsLoadRequested);
    on<EventUpdateRequested>(_onEventUpdateRequested);
    on<EventDeleteRequested>(_onEventDeleteRequested);
  }

  String _extractErrorMessage(
    Object error, {
    required String fallback,
  }) {
    var message = error.toString();

    // Typical Dart Exception stringification: "Exception: <message>"
    message = message.replaceFirst('Exception: ', '').trim();

    // EventService wraps server message into "Ошибка ...: <serverMessage>"
    const knownPrefixes = <String>[
      'Ошибка участия в событии: ',
      'Ошибка обновления события: ',
      'Ошибка отмены участия: ',
      'Ошибка загрузки события: ',
      'Ошибка загрузки событий: ',
      'Ошибка создания события: ',
      'Ошибка удаления события: ',
      'Не удалось получить токен авторизации',
    ];

    for (final prefix in knownPrefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
        break;
      }
    }

    // If it still looks like a wrapper chain, keep the deepest part.
    final lastColon = message.lastIndexOf(': ');
    if (lastColon != -1 && lastColon + 2 < message.length) {
      final tail = message.substring(lastColon + 2).trim();
      if (tail.isNotEmpty) message = tail;
    }

    if (message.isEmpty) return fallback;
    return message;
  }

  List<EventModel> _mergeEventsById(
    List<EventModel> existing,
    List<EventModel> incoming,
  ) {
    final merged = <String, EventModel>{
      for (final item in existing) item.id: item,
    };
    for (final item in incoming) {
      merged[item.id] = item;
    }
    return merged.values.toList();
  }

  void _onEventsMergeListRequested(
    EventsMergeListRequested event,
    Emitter<EventState> emit,
  ) {
    if (event.events.isEmpty) return;

    if (state is EventsLoaded) {
      final currentState = state as EventsLoaded;
      emit(EventsLoaded(
        events: _mergeEventsById(currentState.events, event.events),
        hasMore: currentState.hasMore,
        currentPage: currentState.currentPage,
        viewportLatitude: currentState.viewportLatitude,
        viewportLongitude: currentState.viewportLongitude,
        viewportRadiusMeters: currentState.viewportRadiusMeters,
      ));
      return;
    }

    emit(EventsLoaded(events: List<EventModel>.from(event.events)));
  }

  Future<void> _onEventsLoadRequested(
    EventsLoadRequested event,
    Emitter<EventState> emit,
  ) async {
    final bool isViewportLoad =
        event.latitude != null && event.longitude != null;

    if (event.page == 1 && !event.silent && !event.skipCache) {
      if (!event.mergeWithExisting && !isViewportLoad) {
        final cachedEvents =
            await _eventService.getCachedEvents(category: event.category);
        if (cachedEvents.isNotEmpty) {
          emit(EventsLoaded(
            events: cachedEvents,
            hasMore: cachedEvents.length >= event.limit,
            currentPage: 1,
          ));
        } else {
          emit(const EventsLoading());
        }
      } else if (!event.mergeWithExisting && state is! EventsLoaded) {
        emit(const EventsLoading());
      }
    }

    try {
      final events = await _eventService.getEvents(
        category: event.category,
        latitude: event.latitude,
        longitude: event.longitude,
        maxDistance: event.maxDistance,
        page: event.page,
        limit: event.limit,
        writeCache: !isViewportLoad,
      );

      if (state is EventsLoaded && event.mergeWithExisting) {
        final currentState = state as EventsLoaded;
        emit(EventsLoaded(
          events: _mergeEventsById(currentState.events, events),
          hasMore: events.length >= event.limit,
          currentPage: event.page,
          viewportLatitude: event.latitude ?? currentState.viewportLatitude,
          viewportLongitude: event.longitude ?? currentState.viewportLongitude,
          viewportRadiusMeters:
              event.maxDistance ?? currentState.viewportRadiusMeters,
        ));
      } else if (state is EventsLoaded && event.page > 1) {
        final currentState = state as EventsLoaded;
        emit(EventsLoaded(
          events: [...currentState.events, ...events],
          hasMore: events.length >= event.limit,
          currentPage: event.page,
          viewportLatitude: currentState.viewportLatitude,
          viewportLongitude: currentState.viewportLongitude,
          viewportRadiusMeters: currentState.viewportRadiusMeters,
        ));
      } else {
        emit(EventsLoaded(
          events: events,
          hasMore: events.length >= event.limit,
          currentPage: event.page,
          viewportLatitude: event.latitude,
          viewportLongitude: event.longitude,
          viewportRadiusMeters: event.maxDistance,
        ));
      }
    } catch (e) {
      if (event.silent && state is EventsLoaded) {
        return;
      }
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось загрузить события',
          ),
        ),
      );
    }
  }

  Future<void> _onEventDetailLoadRequested(
    EventDetailLoadRequested event,
    Emitter<EventState> emit,
  ) async {
    if (!event.silent) {
      emit(const EventDetailLoading());
    }

    try {
      final eventModel = await _eventService.getEventById(event.eventId);
      emit(EventDetailLoaded(eventModel));
    } catch (e) {
      if (!event.silent) {
        emit(
          EventError(
            _extractErrorMessage(
              e,
              fallback: 'Не удалось загрузить событие',
            ),
          ),
        );
      }
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
        imageUrls: event.imageUrls,
        isOnline: event.isOnline,
        maxParticipants: event.maxParticipants,
        minAge: event.minAge,
        maxAge: event.maxAge,
      );

      await _eventService.clearEventsCache();
      EventRefreshBus.instance.notify();
      emit(EventCreated(eventModel));
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось создать событие',
          ),
        ),
      );
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
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось загрузить фото',
          ),
        ),
      );
    }
  }

  Future<void> _onEventParticipateRequested(
    EventParticipateRequested event,
    Emitter<EventState> emit,
  ) async {
    try {
      EventModel? eventModel;
      final current = state;
      if (current is EventDetailLoaded && current.event.id == event.eventId) {
        eventModel = current.event;
      } else {
        eventModel = await _eventService.getEventById(event.eventId);
      }

      if (_isEventFinished(eventModel.actualEndDateTime)) {
        emit(const EventError(EventMessages.eventFinishedParticipationUnavailable));
        return;
      }

      emit(const EventParticipationUpdating());
      await _eventService.participateInEvent(event.eventId, event.status);
      emit(const EventParticipationUpdated());
      add(EventDetailLoadRequested(event.eventId));
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось участвовать в событии',
          ),
        ),
      );
    }
  }

  bool _isEventFinished(DateTime actualEndDateTime) {
    return !actualEndDateTime.toUtc().isAfter(DateTime.now().toUtc());
  }

  Future<void> _onEventCancelParticipationRequested(
    EventCancelParticipationRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventParticipationUpdating());

    try {
      await _eventService.cancelParticipation(event.eventId);
      emit(const EventParticipationUpdated());
      // Перезагрузим данные события после отмены
      add(EventDetailLoadRequested(event.eventId));
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось отменить участие',
          ),
        ),
      );
    }
  }

  Future<void> _onEventParticipantsLoadRequested(
    EventParticipantsLoadRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventParticipantsLoading());

    try {
      final participants = await _eventService.getEventParticipants(event.eventId);
      emit(EventParticipantsLoaded(participants));
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось загрузить участников',
          ),
        ),
      );
    }
  }

  Future<void> _onEventUpdateRequested(
    EventUpdateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventUpdating());

    try {
      final eventModel = await _eventService.updateEvent(
        eventId: event.eventId,
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
        imageUrls: event.imageUrls,
        isOnline: event.isOnline,
        maxParticipants: event.maxParticipants,
        minAge: event.minAge,
        maxAge: event.maxAge,
      );

      emit(EventUpdated(eventModel));
      await _eventService.clearEventsCache();
      EventRefreshBus.instance.notify();
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось обновить событие',
          ),
        ),
      );
    }
  }

  Future<void> _onEventDeleteRequested(
    EventDeleteRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventDeleting());

    try {
      await _eventService.deleteEvent(event.eventId);
      await _eventService.clearEventsCache();
      EventRefreshBus.instance.notify();
      emit(const EventDeleted());
    } catch (e) {
      emit(
        EventError(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось удалить событие',
          ),
        ),
      );
    }
  }
}
