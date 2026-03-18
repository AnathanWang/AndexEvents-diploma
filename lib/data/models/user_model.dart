import '../../core/config/app_config.dart';

/// Модель пользователя
class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? coverImageUrl;
  final List<String> photos;
  final String? bio;
  final List<String> interests;
  final Map<String, dynamic>? socialLinks;
  final int? age;
  final String? gender;
  final String? role;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationUpdate;
  final bool isOnboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.coverImageUrl,
    this.photos = const [],
    this.bio,
    this.interests = const [],
    this.socialLinks,
    this.age,
    this.gender,
    this.role,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationUpdate,
    required this.isOnboardingCompleted,
    this.createdAt,
    this.updatedAt,
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      firebaseUid: (json['firebaseUid'] ?? json['supabaseUid']) as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: _normalizeMediaUrl(json['photoUrl'] as String?),
      coverImageUrl: _normalizeMediaUrl(json['coverImageUrl'] as String?),
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => _normalizeMediaUrl(e as String) ?? e)
              .toList() ??
          [],
      bio: json['bio'] as String?,
      interests:
          (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      socialLinks: json['socialLinks'] as Map<String, dynamic>?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      role: json['role'] as String?,
      lastLatitude: (json['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (json['lastLongitude'] as num?)?.toDouble(),
      lastLocationUpdate: json['lastLocationUpdate'] != null
          ? DateTime.parse(json['lastLocationUpdate'] as String)
          : null,
      isOnboardingCompleted: json['isOnboardingCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'coverImageUrl': coverImageUrl,
      'photos': photos,
      'bio': bio,
      'interests': interests,
      'socialLinks': socialLinks,
      'age': age,
      'gender': gender,
      'role': role,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
      'isOnboardingCompleted': isOnboardingCompleted,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? coverImageUrl,
    List<String>? photos,
    String? bio,
    List<String>? interests,
    Map<String, dynamic>? socialLinks,
    int? age,
    String? gender,
    String? role,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastLocationUpdate,
    bool? isOnboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      socialLinks: socialLinks ?? this.socialLinks,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
