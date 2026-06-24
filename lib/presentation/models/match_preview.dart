import 'dart:math' as math;

import '../../data/models/user_model.dart';
import '../../core/utils/match_recommendation_utils.dart';

class MatchPreview {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? photoUrl;
  final List<String> photos;
  final String? bio;
  final List<String> interests;
  final int matchPercentage;
  final List<String> commonInterests;
  final double? latitude;
  final double? longitude;
  final UserModel userModel; // Ссылка на полную модель пользователя

  const MatchPreview({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.photoUrl,
    this.photos = const <String>[],
    this.bio,
    this.interests = const <String>[],
    required this.matchPercentage,
    this.commonInterests = const <String>[],
    this.latitude,
    this.longitude,
    required this.userModel,
  });

  /// Создать MatchPreview из UserModel
  factory MatchPreview.fromUserModel(
    UserModel user, {
    List<String> currentUserInterests = const <String>[],
    UserModel? currentUser,
  }) {
    // Stable score-based matching (interests + distance + profile completeness).
    final matchPercentage = _scoreToPercent(
      candidate: user,
      currentUser: currentUser,
      fallbackInterests: currentUserInterests,
    );

    // Получение общих интересов
    final commonInterests = _getCommonInterests(
      currentUserInterests,
      user.interests,
    );

    final name = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email.split('@').first;

    return MatchPreview(
      id: user.id,
      name: name,
      age: user.age,
      gender: user.gender,
      photoUrl: user.photoUrl,
      photos: user.photos,
      bio: user.bio ?? 'Нет описания',
      interests: user.interests,
      matchPercentage: matchPercentage,
      commonInterests: commonInterests,
      latitude: user.lastLatitude,
      longitude: user.lastLongitude,
      userModel: user,
    );
  }

  static int _scoreToPercent({
    required UserModel candidate,
    required UserModel? currentUser,
    required List<String> fallbackInterests,
  }) {
    // If we don't have full currentUser model, keep legacy interest-only behavior.
    if (currentUser == null) {
      final a = fallbackInterests
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final b = candidate.interests
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (a.isEmpty && b.isEmpty) return 50;
      final union = a.union(b).length;
      if (union == 0) return 50;
      final similarity = a.intersection(b).length / union;
      return (50 + similarity * 50).round().clamp(0, 100);
    }

    final score = MatchRecommendationUtils.scoreUser(
      candidate: candidate,
      currentUser: currentUser,
    );

    // Convert score to 0..100 in a stable way (logistic-ish without extra deps).
    // Tuned so typical scores map to a wide visible range.
    final centered = score - 120;
    final percent = 100 / (1 + (math.exp(-centered / 120)));
    return percent.round().clamp(0, 100);
  }

  /// Получить общие интересы (пересечение), максимум 3
  static List<String> _getCommonInterests(
    List<String> currentUserInterests,
    List<String> otherUserInterests,
  ) {
    final a = currentUserInterests
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final b = otherUserInterests
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final common = a.intersection(b).toList()..sort();
    return common.take(3).toList();
  }

  /// Построить subtitle из возраста и пола
  static String _buildSubtitle(int? age, String? gender) {
    final parts = <String>[];

    if (age != null) {
      parts.add('$age лет');
    }

    if (gender != null) {
      final genderLabel = gender.toLowerCase() == 'male' ? 'М' : 'Ж';
      parts.add(genderLabel);
    }

    return parts.isEmpty ? 'Пользователь' : parts.join(', ');
  }

  /// Получить subtitle для отображения
  String get subtitle {
    final subtitleText = _buildSubtitle(age, gender);
    return subtitleText;
  }

  /// Получить аватар или первое фото
  String? get avatar => photoUrl ?? (photos.isNotEmpty ? photos.first : null);
}
