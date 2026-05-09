import 'package:flutter/material.dart';

import '../../../data/models/admin_audit_log_model.dart';
import '../../../data/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_screen_scaffold.dart';
import '../widgets/admin_state_view.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _error;
  List<AdminAuditLogModel> _logs = const <AdminAuditLogModel>[];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await _userService.getAdminAuditLogs(limit: 200);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить журнал: $e';
      });
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  String _detailsText(AdminAuditLogModel log) {
    final fromRole = (log.details['fromRole'] ?? '').toString();
    final toRole = (log.details['toRole'] ?? '').toString();
    if (fromRole.isNotEmpty || toRole.isNotEmpty) {
      return 'Роль: $fromRole -> $toRole';
    }
    return 'Без деталей';
  }

  @override
  Widget build(BuildContext context) {
    return AdminScreenScaffold(
      title: 'Журнал действий админа',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadLogs,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _isLoading
          ? const AdminStateView.loading()
          : _error != null
              ? AdminStateView.error(
                  title: 'Не удалось загрузить журнал',
                  message: _error,
                  actionLabel: 'Повторить',
                  onAction: _loadLogs,
                )
              : _logs.isEmpty
                  ? const AdminStateView.empty(
                      title: 'Журнал пока пуст',
                      message: 'Здесь будут отображаться действия администраторов.',
                      icon: Icons.history_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLogs,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.action,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Когда: ${_formatDate(log.createdAt)}',
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.62),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Кто: ${log.actorUserId}',
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.62),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Цель: ${log.targetUserId ?? '-'}',
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.62),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _detailsText(log),
                                  style: TextStyle(
                                    color: AppColors.dark.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
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
