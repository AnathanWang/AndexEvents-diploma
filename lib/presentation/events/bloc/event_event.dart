import 'package:equatable/equatable.dart';

/// События для EventBloc
abstract class EventEvent extends Equatable {
  const EventEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить список событий
class EventsLoadRequested extends EventEvent {
  final String? category;
  final double? latitude;
  final double? longitude;
  final int? maxDistance;
  final int page;

  const EventsLoadRequested({
    this.category,
    this.latitude,
    this.longitude,
    this.maxDistance,
    this.page = 1,
  });

  @override
  List<Object?> get props => [category, latitude, longitude, maxDistance, page];
}

/// Загрузить детали события
class EventDetailLoadRequested extends EventEvent {
  final String eventId;

  const EventDetailLoadRequested(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

/// Создать событие
class EventCreateRequested extends EventEvent {
  final String title;
  final String description;
  final String category;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime dateTime;
  final DateTime? endDateTime;
  final double price;
  final String? imageUrl;
  final bool isOnline;
  final int? maxParticipants;
  final int? minAge;
  final int? maxAge;

  const EventCreateRequested({
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.dateTime,
    this.endDateTime,
    required this.price,
    this.imageUrl,
    required this.isOnline,
    this.maxParticipants,
    this.minAge,
    this.maxAge,
  });

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        location,
        latitude,
        longitude,
        dateTime,
        endDateTime,
        price,
        imageUrl,
        isOnline,
        maxParticipants,
        minAge,
        maxAge,
      ];
}

/// Загрузить фото события
class EventPhotoUploadRequested extends EventEvent {
  final String photoPath;

  const EventPhotoUploadRequested(this.photoPath);

  @override
  List<Object?> get props => [photoPath];
}

/// Участвовать в событии
class EventParticipateRequested extends EventEvent {
  final String eventId;
  final String status; // INTERESTED или GOING

  const EventParticipateRequested({
    required this.eventId,
    required this.status,
  });

  @override
  List<Object?> get props => [eventId, status];
}

/// Отменить участие в событии
class EventCancelParticipationRequested extends EventEvent {
  final String eventId;

  const EventCancelParticipationRequested(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

/// Загрузить участников события
class EventParticipantsLoadRequested extends EventEvent {
  final String eventId;

  const EventParticipantsLoadRequested(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

/// Обновить событие
class EventUpdateRequested extends EventEvent {
  final String eventId;
  final String? title;
  final String? description;
  final String? category;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? dateTime;
  final DateTime? endDateTime;
  final double? price;
  final String? imageUrl;
  final bool? isOnline;
  final int? maxParticipants;
  final int? minAge;
  final int? maxAge;

  const EventUpdateRequested({
    required this.eventId,
    this.title,
    this.description,
    this.category,
    this.location,
    this.latitude,
    this.longitude,
    this.dateTime,
    this.endDateTime,
    this.price,
    this.imageUrl,
    this.isOnline,
    this.maxParticipants,
    this.minAge,
    this.maxAge,
  });

  @override
  List<Object?> get props => [
        eventId,
        title,
        description,
        category,
        location,
        latitude,
        longitude,
        dateTime,
        endDateTime,
        price,
        imageUrl,
        isOnline,
        maxParticipants,
        minAge,
        maxAge,
      ];
}

/// Удалить событие
class EventDeleteRequested extends EventEvent {
  final String eventId;

  const EventDeleteRequested(this.eventId);

  @override
  List<Object?> get props => [eventId];
}
