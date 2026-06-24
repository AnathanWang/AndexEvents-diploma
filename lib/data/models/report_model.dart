import '../../core/utils/media_url_utils.dart';

enum UserReportReason {
  spamProfile,
  fakeProfile,
  harassment,
  inappropriatePhotos,
  scam,
  other;

  String get displayName {
    switch (this) {
      case UserReportReason.spamProfile:
        return 'Спам / реклама';
      case UserReportReason.fakeProfile:
        return 'Фейковый профиль';
      case UserReportReason.harassment:
        return 'Оскорбления / домогательства';
      case UserReportReason.inappropriatePhotos:
        return 'Неприемлемые фото';
      case UserReportReason.scam:
        return 'Мошенничество';
      case UserReportReason.other:
        return 'Другое';
    }
  }

  String get toBackendValue {
    switch (this) {
      case UserReportReason.spamProfile:
        return 'SPAM_PROFILE';
      case UserReportReason.fakeProfile:
        return 'FAKE_PROFILE';
      case UserReportReason.harassment:
        return 'HARASSMENT';
      case UserReportReason.inappropriatePhotos:
        return 'INAPPROPRIATE_PHOTOS';
      case UserReportReason.scam:
        return 'SCAM';
      case UserReportReason.other:
        return 'OTHER';
    }
  }
}

enum EventReportReason {
  spam,
  inappropriateContent,
  harassment,
  fakeEvent,
  other;

  String get displayName {
    switch (this) {
      case EventReportReason.spam:
        return 'Спам';
      case EventReportReason.inappropriateContent:
        return 'Неприемлемый контент';
      case EventReportReason.harassment:
        return 'Оскорбления / домогательства';
      case EventReportReason.fakeEvent:
        return 'Фейковое событие';
      case EventReportReason.other:
        return 'Другое';
    }
  }

  String get toBackendValue {
    switch (this) {
      case EventReportReason.spam:
        return 'SPAM';
      case EventReportReason.inappropriateContent:
        return 'INAPPROPRIATE_CONTENT';
      case EventReportReason.harassment:
        return 'HARASSMENT';
      case EventReportReason.fakeEvent:
        return 'FAKE_EVENT';
      case EventReportReason.other:
        return 'OTHER';
    }
  }
}

String reportReasonDisplayName(String backendValue) {
  switch (backendValue) {
    case 'SPAM':
      return 'Спам';
    case 'INAPPROPRIATE_CONTENT':
      return 'Неприемлемый контент';
    case 'HARASSMENT':
      return 'Оскорбления / домогательства';
    case 'FAKE_EVENT':
      return 'Фейковое событие';
    case 'SPAM_PROFILE':
      return 'Спам / реклама';
    case 'FAKE_PROFILE':
      return 'Фейковый профиль';
    case 'INAPPROPRIATE_PHOTOS':
      return 'Неприемлемые фото';
    case 'SCAM':
      return 'Мошенничество';
    case 'OTHER':
    default:
      return 'Другое';
  }
}

class ReportModel {
  final String id;
  final String reporterId;
  final String? targetUserId;
  final String? targetEventId;
  final String reason;
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
      'reason': reason,
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
      reason: (json['reason'] as String?) ?? 'OTHER',
      details: json['details'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class ReportUserSummary {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  ReportUserSummary({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  factory ReportUserSummary.fromJson(Map<String, dynamic> json) {
    return ReportUserSummary(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photoUrl: MediaUrlUtils.normalize(json['photoUrl'] as String?),
    );
  }
}

class ReportEventSummary {
  final String id;
  final String? title;
  final String? imageUrl;

  ReportEventSummary({
    required this.id,
    this.title,
    this.imageUrl,
  });

  factory ReportEventSummary.fromJson(Map<String, dynamic> json) {
    return ReportEventSummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      imageUrl: MediaUrlUtils.normalize(json['imageUrl'] as String?),
    );
  }
}

class EnrichedReportModel {
  final ReportModel report;
  final ReportUserSummary? reporter;
  final ReportUserSummary? targetUser;
  final ReportEventSummary? targetEvent;

  EnrichedReportModel({
    required this.report,
    this.reporter,
    this.targetUser,
    this.targetEvent,
  });

  factory EnrichedReportModel.fromJson(Map<String, dynamic> json) {
    return EnrichedReportModel(
      report: ReportModel.fromJson(json['report'] as Map<String, dynamic>),
      reporter: json['reporter'] is Map<String, dynamic>
          ? ReportUserSummary.fromJson(json['reporter'] as Map<String, dynamic>)
          : null,
      targetUser: json['targetUser'] is Map<String, dynamic>
          ? ReportUserSummary.fromJson(json['targetUser'] as Map<String, dynamic>)
          : null,
      targetEvent: json['targetEvent'] is Map<String, dynamic>
          ? ReportEventSummary.fromJson(json['targetEvent'] as Map<String, dynamic>)
          : null,
    );
  }
}
