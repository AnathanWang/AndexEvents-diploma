import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/report_model.dart';

void main() {
  group('ReportModel', () {
    test('should correctly serialize to JSON', () {
      final now = DateTime.now();
      final report = ReportModel(
        id: 'report_123',
        reporterId: 'user_1',
        targetUserId: 'user_2',
        reason: ReportReason.spam,
        details: 'Spam details',
        createdAt: now,
      );

      final json = report.toJson();

      expect(json['id'], 'report_123');
      expect(json['reporter_id'], 'user_1');
      expect(json['target_user_id'], 'user_2');
      expect(json['reason'], 'SPAM');
      expect(json['details'], 'Spam details');
      expect(json['status'], 'PENDING');
      expect(json['created_at'], now.toIso8601String());
    });

    test('ReportReason enum should return correct backend values', () {
      expect(ReportReason.spam.toBackendValue, 'SPAM');
      expect(ReportReason.inappropriateContent.toBackendValue, 'INAPPROPRIATE_CONTENT');
      expect(ReportReason.harassment.toBackendValue, 'HARASSMENT');
      expect(ReportReason.fakeProfile.toBackendValue, 'FAKE_PROFILE');
      expect(ReportReason.other.toBackendValue, 'OTHER');
    });

    test('ReportReason enum should return correct display names', () {
      expect(ReportReason.spam.displayName, 'Spam');
      expect(ReportReason.inappropriateContent.displayName, 'Inappropriate Content');
      expect(ReportReason.harassment.displayName, 'Harassment');
      expect(ReportReason.fakeProfile.displayName, 'Fake Profile');
      expect(ReportReason.other.displayName, 'Other');
    });
  });
}
