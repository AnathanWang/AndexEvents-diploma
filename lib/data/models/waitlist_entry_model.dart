import 'participant_model.dart';

class WaitlistEntryModel {
  const WaitlistEntryModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  final String id;
  final String eventId;
  final String userId;
  final String status; // PENDING/APPROVED/REJECTED
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserInfo user;

  factory WaitlistEntryModel.fromJson(Map<String, dynamic> json) {
    return WaitlistEntryModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

