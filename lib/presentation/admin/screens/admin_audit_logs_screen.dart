import 'package:flutter/material.dart';

import '../../../data/models/admin_audit_log_model.dart';
import '../../../data/services/user_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Журнал действий админа'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2F355E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 52, color: Color(0xFF9E9E9E)),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _loadLogs, child: const Text('Повторить')),
                  ],
                ),
              ),
            )
          : _logs.isEmpty
          ? const Center(
              child: Text(
                'Журнал пока пуст',
                style: TextStyle(color: Color(0xFF7D85B0)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE3FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.action,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F355E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Когда: ${_formatDate(log.createdAt)}',
                          style: const TextStyle(color: Color(0xFF6F789E), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Кто: ${log.actorUserId}',
                          style: const TextStyle(color: Color(0xFF6F789E), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Цель: ${log.targetUserId ?? '-'}',
                          style: const TextStyle(color: Color(0xFF6F789E), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _detailsText(log),
                          style: const TextStyle(
                            color: Color(0xFF4F5887),
                            fontWeight: FontWeight.w600,
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
