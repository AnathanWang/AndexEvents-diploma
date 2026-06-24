import 'package:equatable/equatable.dart';

import '../../../data/models/event_model.dart';

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
  final int limit;

  /// Добавить к уже загруженным (для карты при перемещении камеры).
  final bool mergeWithExisting;

  /// Не показывать полноэкранный лоадер (фоновая подгрузка viewport).
  final bool silent;

  /// Пропустить локальный кэш и сразу запросить сервер.
  final bool skipCache;

  const EventsLoadRequested({
    this.category,
    this.latitude,
    this.longitude,
    this.maxDistance,
    this.page = 1,
    this.limit = 20,
    this.mergeWithExisting = false,
    this.silent = false,
    this.skipCache = false,
  });

  @override
  List<Object?> get props => [
    category,
    latitude,
    longitude,
    maxDistance,
    page,
    limit,
    mergeWithExisting,
    silent,
    skipCache,
  ];
}

/// Добавить/обновить события в уже загруженном списке (например, сразу после создания).
class EventsMergeListRequested extends EventEvent {
  final List<EventModel> events;

  const EventsMergeListRequested(this.events);

  @override
  List<Object?> get props => [events];
}

/// Загрузить детали события
class EventDetailLoadRequested extends EventEvent {
  final String eventId;
  final bool silent;

  const EventDetailLoadRequested(this.eventId, {this.silent = false});

  @override
  List<Object?> get props => [eventId, silent];
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
  final List<String>? imageUrls;
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
    this.imageUrls,
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
        imageUrls,
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
  final List<String>? imageUrls;
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
    this.imageUrls,
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
        imageUrls,
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
