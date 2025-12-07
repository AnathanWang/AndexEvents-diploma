import 'package:equatable/equatable.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/participant_model.dart';

/// Состояния для EventBloc
abstract class EventState extends Equatable {
  const EventState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class EventInitial extends EventState {
  const EventInitial();
}

/// Загрузка списка событий
class EventsLoading extends EventState {
  const EventsLoading();
}

/// События загружены
class EventsLoaded extends EventState {
  final List<EventModel> events;
  final bool hasMore;
  final int currentPage;

  const EventsLoaded({
    required this.events,
    this.hasMore = true,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [events, hasMore, currentPage];

  EventsLoaded copyWith({
    List<EventModel>? events,
    bool? hasMore,
    int? currentPage,
  }) {
    return EventsLoaded(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Ближайшие события загружены
class NearbyEventsLoaded extends EventState {
  final List<EventModel> events;
  final Map<String, double> distances;

  const NearbyEventsLoaded({
    required this.events,
    required this.distances,
  });

  @override
  List<Object?> get props => [events, distances];
}

/// Загрузка детали события
class EventDetailLoading extends EventState {
  const EventDetailLoading();
}

/// Детали события загружены
class EventDetailLoaded extends EventState {
  final EventModel event;

  const EventDetailLoaded(this.event);

  @override
  List<Object?> get props => [event];
}

/// Создание события
class EventCreating extends EventState {
  const EventCreating();
}

/// Событие создано
class EventCreated extends EventState {
  final EventModel event;

  const EventCreated(this.event);

  @override
  List<Object?> get props => [event];
}

/// Загрузка фото
class EventPhotoUploading extends EventState {
  const EventPhotoUploading();
}

/// Фото загружено
class EventPhotoUploaded extends EventState {
  final String photoUrl;

  const EventPhotoUploaded(this.photoUrl);

  @override
  List<Object?> get props => [photoUrl];
}

/// Обновление участия
class EventParticipationUpdating extends EventState {
  const EventParticipationUpdating();
}

/// Участие обновлено
class EventParticipationUpdated extends EventState {
  const EventParticipationUpdated();
}

/// Загрузка участников события
class EventParticipantsLoading extends EventState {
  const EventParticipantsLoading();
}

/// Участники события загружены
class EventParticipantsLoaded extends EventState {
  final List<ParticipantModel> participants;

  const EventParticipantsLoaded(this.participants);

  @override
  List<Object?> get props => [participants];
}

/// Ошибка
class EventError extends EventState {
  final String message;

  const EventError(this.message);

  @override
  List<Object?> get props => [message];
}
