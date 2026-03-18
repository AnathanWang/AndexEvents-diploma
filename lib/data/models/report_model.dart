enum ReportReason {
  spam,
  inappropriateContent,
  harassment,
  fakeEvent,
  other;

  String get displayName {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.inappropriateContent:
        return 'Inappropriate Content';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.fakeEvent:
        return 'Fake Event';
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
      case ReportReason.fakeEvent:
        return 'FAKE_EVENT';
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
      'reporterId': reporterId,
      'targetUserId': targetUserId,
      'targetEventId': targetEventId,
      'reason': reason.toBackendValue,
      'details': details,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      reporterId: json['reporterId'] as String,
      targetUserId: json['targetUserId'] as String?,
      targetEventId: json['targetEventId'] as String?,
      reason: _reasonFromString(json['reason'] as String?),
      details: json['details'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  static ReportReason _reasonFromString(String? value) {
    switch (value) {
      case 'SPAM':
        return ReportReason.spam;
      case 'INAPPROPRIATE_CONTENT':
        return ReportReason.inappropriateContent;
      case 'HARASSMENT':
        return ReportReason.harassment;
      case 'FAKE_EVENT':
        return ReportReason.fakeEvent;
      default:
        return ReportReason.other;
    }
  }
}
