import 'package:flutter/material.dart';

import '../../../data/models/event_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/report_service.dart';

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
      final reports = await _reportService.getReports();
      final pendingEventReports = reports
          .where(
            (r) =>
                r.status.toUpperCase() == 'PENDING' &&
                (r.targetEventId?.isNotEmpty ?? false),
          )
          .toList();

      final futures = pendingEventReports.map((report) async {
        EventModel? event;
        try {
          event = await _eventService.getEventById(report.targetEventId!);
        } catch (_) {
          event = null;
        }
        return _EventModerationItem(report: report, event: event);
      }).toList();

      final resolved = await Future.wait(futures);

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

  Future<void> _resolveReport(ReportModel report, String resolution) async {
    if (_actionInProgress.contains(report.id)) return;
    setState(() {
      _actionInProgress.add(report.id);
    });

    try {
      await _reportService.resolveReport(report.id, resolution);
      await _loadModerationQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Жалоба обработана: $resolution')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обработки: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(report.id);
        });
      }
    }
  }

  Future<void> _rejectEvent(_EventModerationItem item) async {
    final report = item.report;
    final event = item.event;

    if (_actionInProgress.contains(report.id)) return;
    setState(() {
      _actionInProgress.add(report.id);
    });

    try {
      if (event != null) {
        // С backend текущей версии это сработает только если у модератора есть право удаления.
        await _eventService.deleteEvent(event.id);
      }
      await _reportService.resolveReport(report.id, 'RESOLVED');
      await _loadModerationQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие отклонено, жалоба закрыта')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отклонить событие: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(report.id);
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
                'Нет активных жалоб на события',
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
                  final report = item.report;
                  final event = item.event;
                  final inProgress = _actionInProgress.contains(report.id);

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
                                event?.title ?? 'Событие недоступно',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F355E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Причина: ${report.reason.displayName}',
                          style: const TextStyle(
                            color: Color(0xFF6B74A6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (report.details?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            report.details!,
                            style: const TextStyle(
                              color: Color(0xFF7E86AE),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (event != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Локация: ${event.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF8A92BA)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: inProgress
                                    ? null
                                    : () => _resolveReport(report, 'DISMISSED'),
                                child: const Text('Отклонить жалобу'),
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
                                child: Text(
                                  event == null
                                      ? 'Закрыть жалобу'
                                      : 'Отклонить событие',
                                ),
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
  const _EventModerationItem({required this.report, required this.event});

  final ReportModel report;
  final EventModel? event;
}
