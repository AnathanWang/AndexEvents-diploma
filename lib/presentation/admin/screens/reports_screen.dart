import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:andexevents/data/models/report_model.dart';
import 'package:andexevents/data/services/report_service.dart';
import 'package:andexevents/presentation/admin/widgets/admin_gradient_background.dart';
import '../../../core/theme/app_colors.dart';

const Color _secondaryTextColor = Color(0xFF5E6D86);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _actionInProgress = <String>{};
  String _filterStatus = 'ALL';

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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Не удалось загрузить жалобы: $e';
        });
      }
    }
  }

  List<ReportModel> get _filteredReports {
    if (_filterStatus == 'ALL') return _reports;
    return _reports
        .where((r) => r.status.toUpperCase() == _filterStatus)
        .toList();
  }

  Future<void> _resolveReport(ReportModel report, String resolution) async {
    if (_actionInProgress.contains(report.id)) return;
    setState(() => _actionInProgress.add(report.id));

    try {
      await _reportService.resolveReport(report.id, resolution);
      await _loadReports();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Жалоба обновлена: $resolution')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress.remove(report.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdminGradientBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [_buildAppBar(), _buildFilterTabs(), _buildBody()],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Жалобы',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Обработка обращений пользователей',
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadReports,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return SliverToBoxAdapter(
      child: Container(
        height: 50,
        margin: const EdgeInsets.only(top: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildTab('Все', 'ALL'),
            _buildTab('Новые', 'PENDING'),
            _buildTab('Решенные', 'RESOLVED'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFF0961F6).withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : _secondaryTextColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_loadError!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReports,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final reports = _filteredReports;
    if (reports.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                size: 64,
                color: _secondaryTextColor,
              ),
              SizedBox(height: 16),
              Text(
                'Жалоб нет',
                style: TextStyle(color: _secondaryTextColor, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildReportCard(reports[index]),
          childCount: reports.length,
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    final statusColor = report.status.toUpperCase() == 'PENDING'
        ? Colors.orange
        : Colors.green;
    final isWorking = _actionInProgress.contains(report.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF184B94).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              report.status.toUpperCase() == 'PENDING'
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            report.reason.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.dark,
            ),
          ),
          subtitle: Text(
            'От: ${report.reporterId.substring(0, 8)} • ${DateFormat('dd.MM.yyyy').format(report.createdAt)}',
            style: const TextStyle(fontSize: 12, color: _secondaryTextColor),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (report.targetUserId != null)
              _buildInfoRow(
                'Цель (Юзер)',
                report.targetUserId!,
                Icons.person_outline_rounded,
              ),
            if (report.targetEventId != null)
              _buildInfoRow(
                'Цель (Событие)',
                report.targetEventId!,
                Icons.event_note_rounded,
              ),
            if (report.details != null && report.details!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Описание:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.details!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dark,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (report.status.toUpperCase() == 'PENDING') ...[
              const SizedBox(height: 20),
              isWorking
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _resolveReport(report, 'REJECTED'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5E6D86),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD7E2F7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Отклонить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  Color(0xFF0961F6),
                                  Color(0xFF2E8BFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ElevatedButton(
                              onPressed: () =>
                                  _resolveReport(report, 'RESOLVED'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Решить',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _secondaryTextColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: _secondaryTextColor),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
