import 'dart:math' as math;

import '../../data/models/event_model.dart';
import '../../data/models/user_model.dart';

/// Rule-based event feed ranking (no ML): interests, past visits, distance.
class EventRecommendationUtils {
  static const int interestCategoryWeight = 100;
  static const int historyCategoryWeight = 60;
  static const double distancePenaltyPerKm = 2.5;
  static const int maxDistanceBoost = 35;
  static const int participatingPenalty = 80;

  static const Map<String, List<String>> _interestToCategories = {
    'музыка': <String>['concert', 'party'],
    'спорт': <String>['sport'],
    'кино': <String>['cinema'],
    'it': <String>['conference'],
    'искусство': <String>['exhibition', 'theater'],
    'книги': <String>['conference', 'exhibition'],
    'еда': <String>['party', 'other'],
    'путешествия': <String>['exhibition', 'other'],
    'фотография': <String>['exhibition'],
    'мода': <String>['party', 'exhibition'],
    'танцы': <String>['party', 'concert'],
    'игры': <String>['party', 'sport', 'other'],
  };

  static EventRecommendationProfile buildProfile({
    UserModel? user,
    List<EventModel> participatedEvents = const <EventModel>[],
  }) {
    final preferredCategories = <String, int>{};

    for (final interest in user?.interests ?? const <String>[]) {
      final normalized = _normalizeToken(interest);
      for (final category in _interestToCategories[normalized] ?? const <String>[]) {
        preferredCategories[category] =
            (preferredCategories[category] ?? 0) + interestCategoryWeight;
      }
    }

    for (final event in participatedEvents) {
      final category = event.category.trim().toLowerCase();
      if (category.isEmpty) continue;
      preferredCategories[category] =
          (preferredCategories[category] ?? 0) + historyCategoryWeight;
    }

    return EventRecommendationProfile(
      user: user,
      preferredCategories: preferredCategories,
    );
  }

  static int scoreEvent({
    required EventModel event,
    required EventRecommendationProfile profile,
    double? originLatitude,
    double? originLongitude,
  }) {
    var score = 0;
    final category = event.category.trim().toLowerCase();

    score += profile.preferredCategories[category] ?? 0;

    if (!event.isOnline &&
        originLatitude != null &&
        originLongitude != null) {
      final distanceKm = _haversineKm(
        originLatitude,
        originLongitude,
        event.latitude,
        event.longitude,
      );
      score += math.max(0, maxDistanceBoost - distanceKm.round());
      score -= (distanceKm * distancePenaltyPerKm).round();
    } else if (event.isOnline) {
      score += 8;
    }

    score += math.min(event.participantsCount, 15);
    if (event.ratingCount > 0) {
      score += (event.averageRating * 4).round();
    }

    if (event.isParticipating) {
      score -= participatingPenalty;
    }

    return score;
  }

  static List<EventModel> sortEvents({
    required List<EventModel> events,
    required EventRecommendationProfile profile,
    double? originLatitude,
    double? originLongitude,
  }) {
    final scored = events
        .map(
          (event) => (
            event: event,
            score: scoreEvent(
              event: event,
              profile: profile,
              originLatitude: originLatitude,
              originLongitude: originLongitude,
            ),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.event.dateTime.compareTo(b.event.dateTime);
      });

    return scored.map((entry) => entry.event).toList();
  }

  static List<EventModel> recommendedEvents({
    required List<EventModel> events,
    required EventRecommendationProfile profile,
    double? originLatitude,
    double? originLongitude,
    int limit = 8,
    int minScore = 20,
  }) {
    final now = DateTime.now();
    final upcoming = events
        .where((event) => event.actualEndDateTime.toLocal().isAfter(now))
        .where((event) => !event.isParticipating)
        .toList();

    final ranked = sortEvents(
      events: upcoming,
      profile: profile,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );

    final picked = <EventModel>[];
    for (final event in ranked) {
      if (picked.length >= limit) break;
      final score = scoreEvent(
        event: event,
        profile: profile,
        originLatitude: originLatitude,
        originLongitude: originLongitude,
      );
      if (score < minScore && profile.preferredCategories.isNotEmpty) {
        continue;
      }
      picked.add(event);
    }

    if (picked.isEmpty) {
      return ranked.take(math.min(limit, ranked.length)).toList();
    }

    return picked;
  }

  static String _normalizeToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180);
}

class EventRecommendationProfile {
  const EventRecommendationProfile({
    required this.user,
    required this.preferredCategories,
  });

  final UserModel? user;
  final Map<String, int> preferredCategories;

  bool get hasSignals =>
      preferredCategories.isNotEmpty ||
      user?.lastLatitude != null ||
      user?.lastLongitude != null;
}
