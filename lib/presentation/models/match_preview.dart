import '../../data/models/user_model.dart';

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
  }) {
    // Расчет процента совпадения на основе пересечения интересов
    final matchPercentage = _calculateMatchPercentage(
      currentUserInterests,
      user.interests,
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

  /// Расчет процента совпадения по интересам
  ///
  /// Используем Jaccard similarity: |A ∩ B| / |A ∪ B|.
  /// Чтобы UI не выглядел «пустым», базовое значение = 50.
  static int _calculateMatchPercentage(
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

    if (a.isEmpty && b.isEmpty) {
      return 50;
    }

    final intersectionSize = a.intersection(b).length;
    final unionSize = a.union(b).length;
    if (unionSize == 0) {
      return 50;
    }

    final similarity = intersectionSize / unionSize;
    final percent = (50 + similarity * 50).round();
    return percent.clamp(0, 100);
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
