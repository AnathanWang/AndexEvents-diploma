import 'package:flutter/material.dart';

import '../../../data/models/event_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/report_service.dart';
import 'package:intl/intl.dart';

class EventModerationScreen extends StatefulWidget {
  const EventModerationScreen({super.key});

  @override
  State<EventModerationScreen> createState() => _EventModerationScreenState();
}

class _EventModerationScreenState extends State<EventModerationScreen> {
  final ReportService _reportService = ReportService();
  final EventService _eventService = EventService();

  bool _isLoading = true;
  String? _loadError;
  final Set<String> _actionInProgress = <String>{};
  List<_EventModerationItem> _items = <_EventModerationItem>[];

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
        _eventService.getEvents(limit: 500),
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
                    color: const Color(0xFFD9DCEF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: Color(0xFFFF8E53)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Жалобы по событию',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F355E),
                        ),
                      ),
                    ),
                    Text(
                      '${item.pendingReports} pending',
                      style: const TextStyle(
                        color: Color(0xFF7A82AC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'По событию пока нет жалоб',
                      style: TextStyle(color: Color(0xFF7B82AD)),
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
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDE3FF)),
                          ),
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
                                        color: Color(0xFF2F355E),
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
                                        color: isPending
                                            ? const Color(0xFFD16A3A)
                                            : const Color(0xFF2E9E71),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('dd.MM.yyyy HH:mm', 'ru').format(report.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A82AC),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'От: ${report.reporterId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8C95BC),
                                ),
                              ),
                              if ((report.details ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  report.details!.trim(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4D5687),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'ID: ${report.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9AA2C8),
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
                                      foregroundColor: const Color(0xFF9E9E9E),
                                      side: const BorderSide(color: Color(0xFFD6D9EB)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Модерация событий'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2F355E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadModerationQueue,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 52,
                      color: Color(0xFF9E9E9E),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadModerationQueue,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? const Center(
              child: Text(
                'События не найдены',
                style: TextStyle(color: Color(0xFF7B82AD), fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadModerationQueue,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final event = item.event;
                  final inProgress = _actionInProgress.contains(event.id);
                  final lastReport = item.reports.isEmpty ? null : item.reports.first;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDCE3FF)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.report_problem_rounded,
                              color: Color(0xFFFF8E53),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F355E),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: item.pendingReports > 0
                                    ? const Color(0xFFFFEFE8)
                                    : const Color(0xFFEAF8F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Жалоб: ${item.pendingReports}',
                                style: TextStyle(
                                  color: item.pendingReports > 0
                                      ? const Color(0xFFD16A3A)
                                      : const Color(0xFF2E9E71),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (lastReport != null)
                          Text(
                            'Последняя жалоба: ${lastReport.reason.displayName}',
                            style: const TextStyle(
                              color: Color(0xFF6B74A6),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          const Text(
                            'Жалоб на событие нет',
                            style: TextStyle(
                              color: Color(0xFF6B74A6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (lastReport?.details?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            lastReport!.details!,
                            style: const TextStyle(
                              color: Color(0xFF7E86AE),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Локация: ${event.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF8A92BA)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _showEventReportsDialog(item),
                                child: const Text('Смотреть жалобы'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: inProgress
                                    ? null
                                    : () => _dismissPendingReports(item),
                                child: const Text('Отклонить жалобы'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: inProgress
                                    ? null
                                    : () => _rejectEvent(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B6B),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Удалить событие'),
                              ),
                            ),
                          ],
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
