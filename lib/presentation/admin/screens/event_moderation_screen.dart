import 'package:flutter/material.dart';

import '../../../data/models/event_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/models/event_sanction_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/event_sanction_service.dart';
import '../../../data/services/report_service.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_pill.dart';
import '../widgets/admin_screen_scaffold.dart';
import '../widgets/admin_state_view.dart';
import 'package:flutter/services.dart';

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
  List<_EventModerationItem> _items = <_EventModerationItem>[];
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
            (event) => _EventModerationItem(
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

  Future<void> _rejectEvent(_EventModerationItem item) async {
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

  Future<void> _dismissPendingReports(_EventModerationItem item) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обработки жалоб: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(eventId);
        });
      }
    }
  }

  Future<void> _showEventReportsDialog(_EventModerationItem item) async {
    final reports = [...item.reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.dark.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Жалобы по событию',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AdminPill(
                      label: '${item.pendingReports} pending',
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      foregroundColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'По событию пока нет жалоб',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final isPending = report.status.toUpperCase() == 'PENDING';
                        final statusColor = isPending
                            ? const Color(0xFFD16A3A)
                            : const Color(0xFF2E9E71);

                        return AdminCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      report.reason.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? const Color(0xFFFFEFE8)
                                          : const Color(0xFFEAF8F2),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      report.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('dd.MM.yyyy HH:mm', 'ru').format(report.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dark.withValues(alpha: 0.60),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'От: ${report.reporterId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dark.withValues(alpha: 0.60),
                                ),
                              ),
                              if ((report.details ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  report.details!.trim(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.dark.withValues(alpha: 0.78),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              GestureDetector(
                                onLongPress: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: report.id),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('ID жалобы скопирован')),
                                  );
                                },
                                child: Text(
                                  'ID: ${report.id}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.dark.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _dismissSingleEventReport(item, report);
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Отклонить эту жалобу'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppColors.dark.withValues(alpha: 0.70),
                                      side: BorderSide(
                                        color: AppColors.primary.withValues(alpha: 0.14),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEventSanctionsSheet(_EventModerationItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return _EventSanctionsSheet(
          item: item,
          service: _eventSanctionService,
          onChanged: _loadModerationQueue,
        );
      },
    );
  }

  Future<void> _dismissSingleEventReport(
    _EventModerationItem item,
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

  bool _matchesQuery(_EventModerationItem item, String query) {
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
                      message: 'Если появятся жалобы, они будут отображаться здесь.',
                      icon: Icons.event_busy_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadModerationQueue,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return AdminCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    onChanged: (v) => setState(() => _query = v),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Поиск: title / eventId / reporterId / reportId',
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.72),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatusChip(
                                          label: 'Все',
                                          selected: !_pendingOnly,
                                          onTap: () => setState(
                                            () => _pendingOnly = false,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _StatusChip(
                                          label: 'Только pending',
                                          selected: _pendingOnly,
                                          onTap: () => setState(
                                            () => _pendingOnly = true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Показано: ${filtered.length} из ${_items.length}',
                                    style: TextStyle(
                                      color: AppColors.dark.withValues(alpha: 0.58),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final item = filtered[index - 1];
                          final event = item.event;
                          final inProgress =
                              _actionInProgress.contains(event.id);
                          final lastReport =
                              item.reports.isEmpty ? null : item.reports.first;
                          final totalReports = item.reports.length;
                          final lastReportDate = lastReport == null
                              ? null
                              : DateFormat('dd.MM.yyyy HH:mm', 'ru')
                                  .format(lastReport.createdAt);

                          return AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.report_problem_rounded,
                                      color: AppColors.primary.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    AdminPill(
                                      label: 'Жалоб: ${item.pendingReports}',
                                      backgroundColor: item.pendingReports > 0
                                          ? const Color(0xFFFFEFE8)
                                          : const Color(0xFFEAF8F2),
                                      foregroundColor: item.pendingReports > 0
                                          ? const Color(0xFFD16A3A)
                                          : const Color(0xFF2E9E71),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  lastReport != null
                                      ? 'Последняя жалоба: ${lastReport.reason.displayName}'
                                      : 'Жалоб на событие нет',
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Всего: $totalReports • Последняя: ${lastReportDate ?? '-'}',
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (lastReport?.details?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    lastReport!.details!.trim(),
                                    style: TextStyle(
                                      color: AppColors.dark.withValues(alpha: 0.70),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  'Локация: ${event.location}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showEventReportsDialog(item),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.dark.withValues(alpha: 0.72),
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(alpha: 0.14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'Смотреть жалобы',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showEventSanctionsSheet(item),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.dark.withValues(alpha: 0.72),
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(alpha: 0.14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'Санкции',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: inProgress
                                            ? null
                                            : () => _rejectEvent(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFFF6B6B),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Удалить событие',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  onPressed: inProgress
                                      ? null
                                      : () => _dismissPendingReports(item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.dark.withValues(alpha: 0.72),
                                    side: BorderSide(
                                      color: AppColors.primary.withValues(alpha: 0.14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Отклонить жалобы',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _EventModerationItem {
  const _EventModerationItem({required this.event, required this.reports});

  final EventModel event;
  final List<ReportModel> reports;

  int get pendingReports =>
      reports.where((r) => r.status.toUpperCase() == 'PENDING').length;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.dark.withValues(alpha: 0.72),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventSanctionsSheet extends StatefulWidget {
  const _EventSanctionsSheet({
    required this.item,
    required this.service,
    required this.onChanged,
  });

  final _EventModerationItem item;
  final EventSanctionService service;
  final Future<void> Function() onChanged;

  @override
  State<_EventSanctionsSheet> createState() => _EventSanctionsSheetState();
}

class _EventSanctionsSheetState extends State<_EventSanctionsSheet> {
  bool _isLoading = true;
  String? _loadError;
  bool _actionInProgress = false;

  List<EventSanctionModel> _sanctions = <EventSanctionModel>[];
  EventSanctionType _selectedType = EventSanctionType.freezeParticipation;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await widget.service.getActiveSanctions(widget.item.event.id);
      if (!mounted) return;
      setState(() {
        _sanctions = results;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  String _typeLabel(EventSanctionType type) {
    switch (type) {
      case EventSanctionType.hideVisibility:
        return 'Hide';
      case EventSanctionType.freezeParticipation:
        return 'Freeze';
      case EventSanctionType.limitEdits:
        return 'Limit edits';
    }
  }

  Color _typeColor(EventSanctionType type) {
    switch (type) {
      case EventSanctionType.hideVisibility:
        return const Color(0xFF6D4CFF);
      case EventSanctionType.freezeParticipation:
        return const Color(0xFFD16A3A);
      case EventSanctionType.limitEdits:
        return const Color(0xFF2E9E71);
    }
  }

  Future<void> _create() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите причину')),
      );
      return;
    }

    int? days;
    final rawDays = _daysController.text.trim();
    if (rawDays.isNotEmpty) {
      days = int.tryParse(rawDays);
      if (days == null || days <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Срок должен быть числом дней > 0')),
        );
        return;
      }
    }

    setState(() => _actionInProgress = true);
    try {
      await widget.service.createSanction(
        eventId: widget.item.event.id,
        type: _selectedType,
        reason: reason,
        expiresAt: days == null ? null : DateTime.now().add(Duration(days: days)),
      );
      await _eventService.clearEventsCache();
      _reasonController.clear();
      _daysController.clear();
      await _load();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция применена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось применить санкцию: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _revoke(EventSanctionModel sanction) async {
    setState(() => _actionInProgress = true);
    try {
      await widget.service.revokeSanction(sanction.id);
      await _eventService.clearEventsCache();
      await _load();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция отозвана')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отозвать санкцию: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.dark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Санкции события',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AdminCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onLongPress: () async {
                      await Clipboard.setData(
                        ClipboardData(text: event.id),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event ID скопирован')),
                      );
                    },
                    child: Text(
                      'ID: ${event.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.dark.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Не удалось загрузить санкции',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadError!,
                      style: TextStyle(
                        color: AppColors.dark.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _actionInProgress ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Повторить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dark.withValues(alpha: 0.72),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Активные санкции',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        AdminPill(
                          label: '${_sanctions.length}',
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.10),
                          foregroundColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_sanctions.isEmpty)
                      Text(
                        'Нет активных санкций',
                        style: TextStyle(
                          color: AppColors.dark.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      ..._sanctions.map((s) {
                        final typeColor = _typeColor(s.type);
                        final expires = s.expiresAt == null
                            ? null
                            : DateFormat('dd.MM.yyyy', 'ru').format(s.expiresAt!);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AdminCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AdminPill(
                                      label: _typeLabel(s.type),
                                      backgroundColor:
                                          typeColor.withValues(alpha: 0.12),
                                      foregroundColor: typeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    if (expires != null)
                                      Text(
                                        'до $expires',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.dark.withValues(alpha: 0.60),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: _actionInProgress ? null : () => _revoke(s),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.dark.withValues(alpha: 0.72),
                                        side: BorderSide(
                                          color: AppColors.primary.withValues(alpha: 0.14),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Отозвать',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.reason,
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.80),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onLongPress: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: s.id),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ID санкции скопирован')),
                                    );
                                  },
                                  child: Text(
                                    'ID: ${s.id}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.dark.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Назначить санкцию',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusChip(
                            label: _typeLabel(EventSanctionType.hideVisibility),
                            selected: _selectedType == EventSanctionType.hideVisibility,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(
                                      () => _selectedType = EventSanctionType.hideVisibility,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatusChip(
                            label: _typeLabel(EventSanctionType.freezeParticipation),
                            selected: _selectedType ==
                                EventSanctionType.freezeParticipation,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(
                                      () => _selectedType =
                                          EventSanctionType.freezeParticipation,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatusChip(
                            label: _typeLabel(EventSanctionType.limitEdits),
                            selected: _selectedType == EventSanctionType.limitEdits,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(
                                      () => _selectedType = EventSanctionType.limitEdits,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Причина (обязательно)',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Срок (дней) — опционально',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _actionInProgress ? null : _create,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Применить',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
