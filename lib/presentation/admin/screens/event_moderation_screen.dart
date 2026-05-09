import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/event_sanction_service.dart';
import '../../../data/services/report_service.dart';
import '../event_moderation/event_moderation_event_card.dart';
import '../event_moderation/event_moderation_item.dart';
import '../event_moderation/event_moderation_toolbar.dart';
import '../event_moderation/event_sanctions_sheet.dart';
import '../widgets/admin_screen_scaffold.dart';
import '../widgets/admin_state_view.dart';
import '../widgets/moderation_reports_bottom_sheet.dart';

class EventModerationScreen extends StatefulWidget {
  const EventModerationScreen({super.key});

  @override
  State<EventModerationScreen> createState() => _EventModerationScreenState();
}

class _EventModerationScreenState extends State<EventModerationScreen> {
  final ReportService _reportService = ReportService();
  final EventService _eventService = EventService();
  final EventSanctionService _eventSanctionService = EventSanctionService();

  bool _isLoading = true;
  String? _loadError;
  final Set<String> _actionInProgress = <String>{};
  List<EventModerationItem> _items = <EventModerationItem>[];
  String _query = '';
  bool _pendingOnly = false;

  @override
  void initState() {
    super.initState();
    _loadModerationQueue();
  }

  Future<void> _loadModerationQueue() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _eventService.getEventsForModeration(limit: 500),
        _reportService.getEventReports(),
      ]);

      final events = results[0] as List<EventModel>;
      final reports = results[1] as List<ReportModel>;

      final Map<String, List<ReportModel>> reportsByEventId =
          <String, List<ReportModel>>{};

      for (final report in reports) {
        final target = report.targetEventId;
        if (target == null || target.isEmpty) continue;
        reportsByEventId.putIfAbsent(target, () => <ReportModel>[]).add(report);
      }

      for (final reportList in reportsByEventId.values) {
        reportList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final resolved = events
          .map(
            (EventModel event) => EventModerationItem(
              event: event,
              reports: reportsByEventId[event.id] ?? <ReportModel>[],
            ),
          )
          .toList()
        ..sort((a, b) {
          final byPending = b.pendingReports.compareTo(a.pendingReports);
          if (byPending != 0) return byPending;
          return b.event.dateTime.compareTo(a.event.dateTime);
        });

      if (!mounted) return;
      setState(() {
        _items = resolved;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _readableError(
          e,
          fallback: 'Не удалось загрузить очередь модерации событий.',
        );
      });
    }
  }

  String _readableError(Object error, {required String fallback}) {
    if (error is ReportAccessDeniedException) {
      return error.message;
    }

    final message = error.toString();
    if (message.contains('401') || message.contains('403')) {
      return 'Недостаточно прав для доступа к разделу модерации.';
    }

    return fallback;
  }

  Future<void> _rejectEvent(EventModerationItem item) async {
    final eventId = item.event.id;
    final pendingReports = item.reports
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .toList();

    if (_actionInProgress.contains(eventId)) return;
    setState(() {
      _actionInProgress.add(eventId);
    });

    try {
      await _eventService.deleteEvent(eventId);

      for (final report in pendingReports) {
        await _reportService.resolveReport(report.id, 'RESOLVED');
      }

      await _loadModerationQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pendingReports.isEmpty
                ? 'Событие удалено'
                : 'Событие удалено, жалоб закрыто: ${pendingReports.length}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отклонить событие: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(eventId);
        });
      }
    }
  }

  Future<void> _dismissPendingReports(EventModerationItem item) async {
    final eventId = item.event.id;
    final pendingReports = item.reports
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .toList();

    if (pendingReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У события нет активных жалоб')),
      );
      return;
    }

    if (_actionInProgress.contains(eventId)) return;

    setState(() {
      _actionInProgress.add(eventId);
    });

    try {
      for (final report in pendingReports) {
        await _reportService.resolveReport(report.id, 'DISMISSED');
      }

      await _loadModerationQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отклонено жалоб: ${pendingReports.length}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обработки жалоб: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(eventId);
        });
      }
    }
  }

  Future<void> _showEventReportsDialog(EventModerationItem item) async {
    await ModerationReportsBottomSheet.show(
      context: context,
      title: 'Жалобы по событию',
      headerIcon: Icons.flag_rounded,
      reports: item.reports,
      pendingCount: item.pendingReports,
      emptyMessage: 'По событию пока нет жалоб',
      onDismissPendingReport: (report) =>
          _dismissSingleEventReport(item, report),
    );
  }

  Future<void> _showEventSanctionsSheet(EventModerationItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return EventSanctionsSheet(
          item: item,
          service: _eventSanctionService,
          onChanged: _loadModerationQueue,
        );
      },
    );
  }

  Future<void> _dismissSingleEventReport(
    EventModerationItem item,
    ReportModel report,
  ) async {
    final eventId = item.event.id;
    if (_actionInProgress.contains(eventId)) return;

    setState(() {
      _actionInProgress.add(eventId);
    });

    try {
      await _reportService.resolveReport(report.id, 'DISMISSED');
      await _loadModerationQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отклонена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отклонения жалобы: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(eventId);
        });
      }
    }
  }

  bool _matchesQuery(EventModerationItem item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final event = item.event;
    if (event.title.toLowerCase().contains(q)) return true;
    if (event.id.toLowerCase().contains(q)) return true;
    if (event.location.toLowerCase().contains(q)) return true;

    for (final r in item.reports) {
      if (r.id.toLowerCase().contains(q)) return true;
      if (r.reporterId.toLowerCase().contains(q)) return true;
      if ((r.details ?? '').toLowerCase().contains(q)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where((i) => !_pendingOnly || i.pendingReports > 0)
        .where((i) => _matchesQuery(i, _query))
        .toList();

    return AdminScreenScaffold(
      title: 'Модерация событий',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadModerationQueue,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _isLoading
          ? const AdminStateView.loading()
          : _loadError != null
              ? AdminStateView.error(
                  title: 'Не удалось загрузить очередь',
                  message: _loadError,
                  actionLabel: 'Повторить',
                  onAction: _loadModerationQueue,
                )
              : _items.isEmpty
                  ? const AdminStateView.empty(
                      title: 'События не найдены',
                      message:
                          'Если появятся жалобы, они будут отображаться здесь.',
                      icon: Icons.event_busy_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadModerationQueue,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return EventModerationToolbar(
                              onQueryChanged: (v) =>
                                  setState(() => _query = v),
                              pendingOnly: _pendingOnly,
                              onSelectAll: () => setState(
                                () => _pendingOnly = false,
                              ),
                              onSelectPendingOnly: () => setState(
                                () => _pendingOnly = true,
                              ),
                              filteredCount: filtered.length,
                              totalCount: _items.length,
                            );
                          }

                          final item = filtered[index - 1];
                          final event = item.event;
                          final inProgress =
                              _actionInProgress.contains(event.id);

                          return EventModerationEventCard(
                            item: item,
                            inProgress: inProgress,
                            onShowReports: () =>
                                _showEventReportsDialog(item),
                            onShowSanctions: () =>
                                _showEventSanctionsSheet(item),
                            onRejectEvent: () => _rejectEvent(item),
                            onDismissPendingReports: () =>
                                _dismissPendingReports(item),
                          );
                        },
                      ),
                    ),
    );
  }
}
