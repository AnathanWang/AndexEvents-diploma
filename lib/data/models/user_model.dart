/// Модель пользователя
class UserModel {
  final String id;
  final String supabaseUid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final List<String> interests;
  final Map<String, dynamic>? socialLinks;
  final int? age;
  final String? gender;
  final double? lastLatitude;
  final double? lastLongitude;
  final bool isOnboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.supabaseUid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.interests = const [],
    this.socialLinks,
    this.age,
    this.gender,
    this.lastLatitude,
    this.lastLongitude,
    required this.isOnboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      supabaseUid: json['supabaseUid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      socialLinks: json['socialLinks'] as Map<String, dynamic>?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      lastLatitude: (json['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (json['lastLongitude'] as num?)?.toDouble(),
      isOnboardingCompleted: json['isOnboardingCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supabaseUid': supabaseUid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'interests': interests,
      'socialLinks': socialLinks,
      'age': age,
      'gender': gender,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'isOnboardingCompleted': isOnboardingCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? supabaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? bio,
    List<String>? interests,
    Map<String, dynamic>? socialLinks,
    int? age,
    String? gender,
    double? lastLatitude,
    double? lastLongitude,
    bool? isOnboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      supabaseUid: supabaseUid ?? this.supabaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      socialLinks: socialLinks ?? this.socialLinks,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
