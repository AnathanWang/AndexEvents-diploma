enum ReportReason {
  spam,
  inappropriateContent,
  harassment,
  fakeProfile,
  other;

  String get displayName {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.inappropriateContent:
        return 'Inappropriate Content';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.fakeProfile:
        return 'Fake Profile';
      case ReportReason.other:
        return 'Other';
    }
  }

  String get toBackendValue {
    switch (this) {
      case ReportReason.spam:
        return 'SPAM';
      case ReportReason.inappropriateContent:
        return 'INAPPROPRIATE_CONTENT';
      case ReportReason.harassment:
        return 'HARASSMENT';
      case ReportReason.fakeProfile:
        return 'FAKE_PROFILE';
      case ReportReason.other:
        return 'OTHER';
    }
  }
}

class ReportModel {
  final String id;
  final String reporterId;
  final String? targetUserId;
  final String? targetEventId;
  final ReportReason reason;
  final String? details;
  final String status;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    this.targetUserId,
    this.targetEventId,
    required this.reason,
    this.details,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_user_id': targetUserId,
      'target_event_id': targetEventId,
      'reason': reason.toBackendValue,
      'details': details,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
