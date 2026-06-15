import 'dart:math' as math;

import '../../data/models/user_model.dart';
import '../../presentation/models/match_preview.dart';

/// Rule-based ranking for match feeds (no ML).
class MatchRecommendationUtils {
  static const int incomingLikeBoost = 1000;
  static const int sharedGoingEventWeight = 80;
  static const int commonInterestWeight = 120;
  static const double distancePenaltyPerKm = 3;
  static const int profilePhotoBoost = 15;
  static const int profileBioBoost = 5;
  static const int missingPhotoPenalty = 25;
  static const int missingInterestsPenalty = 20;
  static const int missingBioPenalty = 10;
  static const int emptyProfilePenalty = 60;

  static int scoreUser({
    required UserModel candidate,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    var score = 0;

    if (incomingLikeUserIds.contains(candidate.id)) {
      score += incomingLikeBoost;
    }

    score += (sharedGoingEventCounts[candidate.id] ?? 0) * sharedGoingEventWeight;

    score += _commonInterests(
          currentUser.interests,
          candidate.interests,
        ) *
        commonInterestWeight;

    final candidateLat = candidate.lastLatitude;
    final candidateLon = candidate.lastLongitude;
    final originLat = currentUser.lastLatitude;
    final originLon = currentUser.lastLongitude;
    if (candidateLat != null &&
        candidateLon != null &&
        originLat != null &&
        originLon != null) {
      final distanceKm = _haversineKm(
        originLat,
        originLon,
        candidateLat,
        candidateLon,
      );
      score -= (distanceKm * distancePenaltyPerKm).round();
    }

    if (candidate.photoUrl != null && candidate.photoUrl!.trim().isNotEmpty) {
      score += profilePhotoBoost;
    }
    if (candidate.bio != null && candidate.bio!.trim().isNotEmpty) {
      score += profileBioBoost;
    }

    score -= _profileCompletenessPenalty(candidate);

    return score;
  }

  static int _profileCompletenessPenalty(UserModel candidate) {
    final hasPhoto =
        candidate.photoUrl != null && candidate.photoUrl!.trim().isNotEmpty;
    final hasGallery = candidate.photos.isNotEmpty;
    final hasBio = candidate.bio != null && candidate.bio!.trim().isNotEmpty;
    final hasInterests = candidate.interests.isNotEmpty;

    if (!hasPhoto && !hasGallery && !hasBio && !hasInterests) {
      return emptyProfilePenalty;
    }

    var penalty = 0;
    if (!hasPhoto && !hasGallery) {
      penalty += missingPhotoPenalty;
    }
    if (!hasInterests) {
      penalty += missingInterestsPenalty;
    }
    if (!hasBio) {
      penalty += missingBioPenalty;
    }
    return penalty;
  }

  static Map<String, int> buildSharedGoingEventCounts({
    required Set<String> currentUserGoingEventIds,
    required Map<String, Set<String>> candidateGoingEventIdsByUser,
  }) {
    final counts = <String, int>{};
    for (final entry in candidateGoingEventIdsByUser.entries) {
      final shared = entry.value.intersection(currentUserGoingEventIds).length;
      if (shared > 0) {
        counts[entry.key] = shared;
      }
    }
    return counts;
  }

  static Set<String> goingEventIdsFromParticipated(
    List<dynamic> events,
  ) {
    final ids = <String>{};
    for (final event in events) {
      final status = _participationStatus(event);
      final id = _eventId(event);
      if (id != null && status == 'GOING') {
        ids.add(id);
      }
    }
    return ids;
  }

  static String? _participationStatus(dynamic event) {
    if (event is Map<String, dynamic>) {
      return event['userParticipationStatus'] as String?;
    }
    try {
      return event.userParticipationStatus as String?;
    } catch (_) {
      return null;
    }
  }

  static String? _eventId(dynamic event) {
    if (event is Map<String, dynamic>) {
      return event['id'] as String?;
    }
    try {
      return event.id as String?;
    } catch (_) {
      return null;
    }
  }

  static List<UserModel> sortUsers({
    required List<UserModel> users,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    final sorted = List<UserModel>.from(users);
    sorted.sort((UserModel a, UserModel b) {
      final scoreA = scoreUser(
        candidate: a,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final scoreB = scoreUser(
        candidate: b,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) {
        return byScore;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static List<MatchPreview> sortPreviews({
    required List<MatchPreview> previews,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    final sorted = List<MatchPreview>.from(previews);
    sorted.sort((MatchPreview a, MatchPreview b) {
      final scoreA = scoreUser(
        candidate: a.userModel,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final scoreB = scoreUser(
        candidate: b.userModel,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) {
        return byScore;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static int _commonInterests(
    List<String> left,
    List<String> right,
  ) {
    final a = left
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final b = right
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    return a.intersection(b).length;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
