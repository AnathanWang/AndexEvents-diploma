import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/http/api_client.dart';
import '../models/event_review_model.dart';

class EventRatingStats {
  final double averageRating;
  final int ratingCount;
  final int? myRating;

  EventRatingStats({
    required this.averageRating,
    required this.ratingCount,
    this.myRating,
  });

  factory EventRatingStats.fromJson(Map<String, dynamic> json) {
    return EventRatingStats(
      averageRating: (json['averageRating'] as num).toDouble(),
      ratingCount: (json['ratingCount'] as num).toInt(),
      myRating: (json['myRating'] as num?)?.toInt(),
    );
  }
}

class UserRatingStats {
  final double averageRating;
  final int eventsCount;

  UserRatingStats({
    required this.averageRating,
    required this.eventsCount,
  });

  factory UserRatingStats.fromJson(Map<String, dynamic> json) {
    return UserRatingStats(
      averageRating: (json['averageRating'] as num).toDouble(),
      eventsCount: (json['eventsCount'] as num).toInt(),
    );
  }
}

class RatingService {
  final ApiClient _client;

  RatingService(this._client);

  Future<void> rateEvent(String eventId, int rating, {String? comment}) async {
    final http.Response response = await _client.post(
      '/events/$eventId/rating',
      body: <String, dynamic>{
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );

    if (response.statusCode != 200) {
      String message = 'Не удалось оставить отзыв';
      try {
        final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] != null) {
          message = body['message'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<EventRatingStats> getEventRatingStats(String eventId) async {
    final http.Response response = await _client.get(
      '/events/$eventId/rating/stats',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic> data = json['data'] as Map<String, dynamic>;
      return EventRatingStats.fromJson(data);
    }
    throw Exception('Не удалось загрузить статистику рейтинга');
  }

  Future<List<EventReviewModel>> getEventReviews(String eventId) async {
    final http.Response response = await _client.get(
      '/events/$eventId/rating/reviews',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
      final dynamic rawData = json['data'];
      final List<dynamic> data;
      if (rawData is List<dynamic>) {
        data = rawData;
      } else if (rawData is Map<String, dynamic>) {
        data = (rawData['items'] as List<dynamic>?) ??
            (rawData['reviews'] as List<dynamic>?) ??
            <dynamic>[];
      } else {
        data = <dynamic>[];
      }
      return data
          .map((item) => EventReviewModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 204) {
      return <EventReviewModel>[];
    }

    throw Exception('Не удалось загрузить отзывы');
  }

  // Returns null if user has fewer than 3 approved events
  Future<UserRatingStats?> getUserRating(String userId) async {
    final http.Response response = await _client.get(
      '/events/user/$userId/rating',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic> data = json['data'] as Map<String, dynamic>;
      return UserRatingStats.fromJson(data);
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception('Не удалось загрузить рейтинг пользователя');
  }
}
