import 'participant_model.dart';
import '../../core/config/app_config.dart';

/// Модель события
class EventModel {
  final String id;
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
  final List<String> imageUrls;
  final bool isOnline;
  final String status; // PENDING, APPROVED, REJECTED
  final String? rejectionReason;
  final int? maxParticipants;
  final int? minAge;
  final int? maxAge;
  final String? createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Дополнительные поля для UI
  final int participantsCount;
  final bool isParticipating;
  final String? userParticipationStatus;
  final String? creatorName;
  final String? creatorPhotoUrl;
  final List<ParticipantModel> previewParticipants;

  // Рейтинг события
  final double averageRating;
  final int ratingCount;
  final int? myRating;

  DateTime get actualEndDateTime => endDateTime ?? dateTime.add(const Duration(hours: 3));

  const EventModel({
    required this.id,
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
    this.imageUrls = const [],
    required this.isOnline,
    required this.status,
    this.rejectionReason,
    this.maxParticipants,
    this.minAge,
    this.maxAge,
    this.createdById,
    this.createdAt,
    this.updatedAt,
    this.participantsCount = 0,
    this.isParticipating = false,
    this.userParticipationStatus,
    this.creatorName,
    this.creatorPhotoUrl,
    this.previewParticipants = const [],
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.myRating,
  });

  static String? _normalizeMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return rawUrl;

    try {
      final uri = Uri.parse(rawUrl);
      final host = uri.host.toLowerCase();
      final isLoopback =
          host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
      if (!isLoopback) return rawUrl;

      final apiUri = Uri.parse(AppConfig.baseUrl);
      if (apiUri.host.isEmpty) return rawUrl;

      return uri
          .replace(
            scheme: apiUri.scheme.isEmpty ? 'http' : apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    } catch (_) {
      return rawUrl;
    }
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Извлекаем данные организатора из объекта createdBy
    final createdBy = json['createdBy'] as Map<String, dynamic>?;

    // Извлекаем количество участников из _count.participants или participantsCount
    final countData = json['_count'] as Map<String, dynamic>?;
    final participantsCount =
        countData?['participants'] as int? ??
        json['participantsCount'] as int? ??
        0;

    final previewParticipants =
        (json['participants'] as List<dynamic>?)
            ?.map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final normalizedImageUrl = _normalizeMediaUrl(json['imageUrl'] as String?);
    final normalizedImageUrls =
      (json['imageUrls'] as List<dynamic>?)
        ?.map((e) => _normalizeMediaUrl(e?.toString()))
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList() ??
      <String>[];

    if ((normalizedImageUrl ?? '').trim().isNotEmpty &&
      !normalizedImageUrls.contains(normalizedImageUrl)) {
      normalizedImageUrls.insert(0, normalizedImageUrl!);
    }

    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      location: json['location'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      dateTime: DateTime.parse(json['dateTime'] as String),
      endDateTime: json['endDateTime'] != null
          ? DateTime.parse(json['endDateTime'] as String)
          : null,
      price: (json['price'] as num).toDouble(),
        imageUrl: normalizedImageUrl,
        imageUrls: normalizedImageUrls,
      isOnline: json['isOnline'] as bool? ?? false,
      status: json['status'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      maxParticipants: json['maxParticipants'] as int?,
      minAge: json['minAge'] as int?,
      maxAge: json['maxAge'] as int?,
      createdById: json['createdById'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      participantsCount: participantsCount,
      isParticipating: json['isParticipating'] as bool? ?? false,
      userParticipationStatus: json['userParticipationStatus'] as String?,
      creatorName: createdBy?['displayName'] as String?,
      creatorPhotoUrl: _normalizeMediaUrl(createdBy?['photoUrl'] as String?),
      previewParticipants: previewParticipants,
      averageRating: (() {
        final stats = json['ratingStats'] as Map<String, dynamic>?;
        return (stats?['averageRating'] as num?)?.toDouble() ?? 0.0;
      })(),
      ratingCount: (() {
        final stats = json['ratingStats'] as Map<String, dynamic>?;
        return (stats?['ratingCount'] as num?)?.toInt() ?? 0;
      })(),
      myRating: (() {
        final stats = json['ratingStats'] as Map<String, dynamic>?;
        return (stats?['myRating'] as num?)?.toInt();
      })(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'dateTime': dateTime.toUtc().toIso8601String(),
      'endDateTime': endDateTime?.toUtc().toIso8601String(),
      'price': price,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'isOnline': isOnline,
      'status': status,
      'rejectionReason': rejectionReason,
      'maxParticipants': maxParticipants,
      'minAge': minAge,
      'maxAge': maxAge,
      'createdById': createdById,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? dateTime,
    DateTime? endDateTime,
    double? price,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isOnline,
    String? status,
    String? rejectionReason,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
    String? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? participantsCount,
    bool? isParticipating,
    String? userParticipationStatus,
    String? creatorName,
    String? creatorPhotoUrl,
    List<ParticipantModel>? previewParticipants,
    double? averageRating,
    int? ratingCount,
    int? myRating,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dateTime: dateTime ?? this.dateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participantsCount: participantsCount ?? this.participantsCount,
      isParticipating: isParticipating ?? this.isParticipating,
      userParticipationStatus: userParticipationStatus ?? this.userParticipationStatus,
      creatorName: creatorName ?? this.creatorName,
      creatorPhotoUrl: creatorPhotoUrl ?? this.creatorPhotoUrl,
      previewParticipants: previewParticipants ?? this.previewParticipants,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      myRating: myRating ?? this.myRating,
    );
  }
}
