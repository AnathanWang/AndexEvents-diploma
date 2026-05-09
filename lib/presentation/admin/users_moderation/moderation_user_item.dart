import '../../../data/models/report_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_sanction_model.dart';

class ModerationUserItem {
  const ModerationUserItem({
    required this.user,
    required this.reports,
    required this.pendingReports,
    this.activeSanction,
  });

  final UserModel user;
  final List<ReportModel> reports;
  final int pendingReports;
  final UserSanctionModel? activeSanction;
}

String moderationRolePillLabel(String? role) {
  switch ((role ?? '').trim().toUpperCase()) {
    case 'ADMIN':
      return 'ADMIN';
    case 'MODERATOR':
      return 'MODERATOR';
    default:
      return 'USER';
  }
}

String moderationSanctionPillLabel(UserSanctionModel sanction) {
  switch (sanction.type.toUpperCase()) {
    case 'WARNING':
      return 'WARNING';
    case 'MUTE':
      return 'MUTE';
    case 'EVENT_CREATE_BAN':
      return 'EVENT BAN';
    case 'FULL_BAN':
      return 'FULL BAN';
    default:
      return sanction.type;
  }
}
