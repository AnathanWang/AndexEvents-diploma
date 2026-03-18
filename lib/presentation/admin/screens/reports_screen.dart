import 'package:flutter/material.dart';
import 'package:andexevents/data/models/report_model.dart';
import 'package:andexevents/data/services/report_service.dart';
import 'package:andexevents/data/services/user_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final UserService _userService = UserService();
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _actionInProgress = <String>{};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final reports = await _reportService.getReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = _readableError(
            e,
            fallback: 'Не удалось загрузить жалобы',
          );
        });
      }
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
      await _loadReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Жалоба ${report.id} обновлена: $resolution')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обработки жалобы: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(report.id);
        });
      }
    }
  }

  Future<void> _blockAndResolve(ReportModel report) async {
    if (_actionInProgress.contains(report.id)) return;

    final targetUserId = report.targetUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У жалобы нет targetUserId для блокировки'),
        ),
      );
      return;
    }

    setState(() {
      _actionInProgress.add(report.id);
    });

    try {
      await _userService.blockUser(targetUserId);
      await _reportService.resolveReport(report.id, 'RESOLVED');
      await _loadReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пользователь заблокирован, жалоба закрыта'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка блокировки/резолва: $e')));
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
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Жалобы и отчёты',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFFF6B6B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadReports,
              ),
            ],
          ),

          // Reports list
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF5E60CE),
                      ),
                    ),
                  ),
                )
              : _loadError != null
              ? SliverFillRemaining(
                  child: Center(
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
                              fontSize: 15,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadReports,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _reports.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Color(0xFF9E9E9E),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Нет активных жалоб',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final report = _reports[index];
                      final inProgress = _actionInProgress.contains(report.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.all(20),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                20,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getStatusColor(report.status),
                                      _getStatusColor(
                                        report.status,
                                      ).withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _getReasonIcon(report.reason),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                report.reason.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A4D6A),
                                ),
                              ),
                              subtitle: Text(
                                DateFormat(
                                  'dd MMM yyyy, HH:mm',
                                  'ru',
                                ).format(report.createdAt),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    report.status,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusText(report.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(report.status),
                                  ),
                                ),
                              ),
                              children: [
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F2FB),
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow('ID жалобы:', report.id),
                                _buildDetailRow('От:', report.reporterId),
                                _buildDetailRow(
                                  'Пользователь:',
                                  report.targetUserId ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  'Событие:',
                                  report.targetEventId ?? 'N/A',
                                ),
                                if (report.details != null) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Детали:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A4D6A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.details!,
                                    style: const TextStyle(
                                      color: Color(0xFF9E9E9E),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: inProgress
                                            ? null
                                            : () => _resolveReport(
                                                report,
                                                'DISMISSED',
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF9E9E9E,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFE0E0E0),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Отклонить'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: inProgress
                                            ? null
                                            : () => _blockAndResolve(report),
                                        icon: const Icon(Icons.block, size: 16),
                                        label: const Text('Блок'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFF6B6B,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: inProgress
                                            ? null
                                            : () => _resolveReport(
                                                report,
                                                'RESOLVED',
                                              ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Решено'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4ECDC4,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: _reports.length),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Color(0xFF4A4D6A), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Ожидает';
      case 'RESOLVED':
        return 'Решено';
      case 'DISMISSED':
        return 'Отклонено';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFF8E53);
      case 'RESOLVED':
        return const Color(0xFF4ECDC4);
      case 'DISMISSED':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF5E60CE);
    }
  }

  IconData _getReasonIcon(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return Icons.mail_outline_rounded;
      case ReportReason.inappropriateContent:
        return Icons.explicit_rounded;
      case ReportReason.harassment:
        return Icons.back_hand_rounded;
      case ReportReason.fakeEvent:
        return Icons.event_busy_rounded;
      case ReportReason.other:
        return Icons.help_outline_rounded;
    }
  }
}
