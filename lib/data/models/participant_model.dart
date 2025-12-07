/// Модель участника события
class ParticipantModel {
  final String id;
  final String userId;
  final String eventId;
  final String status; // INTERESTED, GOING, MAYBE
  final DateTime joinedAt;
  final DateTime updatedAt;
  final UserInfo user;

  const ParticipantModel({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
    required this.user,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      eventId: json['eventId'] as String,
      status: json['status'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Информация о пользователе в контексте участника
class UserInfo {
  final String id;
  final String displayName;
  final String photoUrl;
  final String email;

  const UserInfo({
    required this.id,
    required this.displayName,
    required this.photoUrl,
    required this.email,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Unknown',
      photoUrl: json['photoUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}
