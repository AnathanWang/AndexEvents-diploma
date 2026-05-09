import '../../../data/models/event_model.dart';
import '../../../data/models/report_model.dart';

class EventModerationItem {
  const EventModerationItem({
    required this.event,
    required this.reports,
  });

  final EventModel event;
  final List<ReportModel> reports;

  int get pendingReports =>
      reports.where((r) => r.status.toUpperCase() == 'PENDING').length;
}
