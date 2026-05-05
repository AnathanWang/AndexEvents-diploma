import 'package:flutter/material.dart';

import '../../../data/models/report_model.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/report_service.dart';
import '../../../data/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'reports_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_pill.dart';
import '../widgets/admin_screen_scaffold.dart';
import '../widgets/admin_state_view.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final ReportService _reportService = ReportService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _loadError;
  String _search = '';
  UserModel? _currentUser;
  final Set<String> _actionInProgress = <String>{};
  List<_ModerationUserItem> _users = <_ModerationUserItem>[];

  bool get _isAdmin =>
      (_currentUser?.role ?? '').trim().toUpperCase() == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final currentUser = await _userService.getCurrentUser();
      final isAdmin =
          (currentUser.role ?? '').trim().toUpperCase() == 'ADMIN';

      final activeSanctions = isAdmin
          ? await _userService.getAdminSanctions(limit: 500)
          : <UserSanctionModel>[];

      final results = await Future.wait<dynamic>([
        _userService.getUsersForModeration(),
        _reportService.getReports(),
      ]);

      final users = results[0] as List<UserModel>;
      final reports = results[1] as List<ReportModel>;

      final Map<String, List<ReportModel>> reportsByUserId =
          <String, List<ReportModel>>{};

      for (final report in reports) {
        final target = report.targetUserId;
        if (target == null || target.isEmpty) continue;
        reportsByUserId.putIfAbsent(target, () => <ReportModel>[]).add(report);
      }

      final Map<String, UserSanctionModel> activeSanctionByUserId =
          <String, UserSanctionModel>{};
      for (final sanction in activeSanctions.where((s) => s.isActive)) {
        final existing = activeSanctionByUserId[sanction.targetUserId];
        if (existing == null || sanction.createdAt.isAfter(existing.createdAt)) {
          activeSanctionByUserId[sanction.targetUserId] = sanction;
        }
      }

      final resolved = users
          .map((user) {
            final userReports = reportsByUserId[user.id] ?? <ReportModel>[];
            final pending = userReports
                .where((r) => r.status.toUpperCase() == 'PENDING')
                .length;

            return _ModerationUserItem(
              user: user,
              reports: userReports,
              pendingReports: pending,
              activeSanction: activeSanctionByUserId[user.id],
            );
          })
          .toList()
        ..sort((a, b) {
          final byPending = b.pendingReports.compareTo(a.pendingReports);
          if (byPending != 0) return byPending;
          return a.user.email.toLowerCase().compareTo(b.user.email.toLowerCase());
        });

      if (!mounted) return;
      setState(() {
        _currentUser = currentUser;
        _users = resolved;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _readableError(
          e,
          fallback: 'Не удалось загрузить пользователей для модерации.',
        );
      });
    }
  }

  Future<void> _changeUserRole(_ModerationUserItem item, String nextRole) async {
    final id = item.user.id;
    final currentRole = (item.user.role ?? 'USER').toUpperCase();
    if (currentRole == nextRole) return;

    if (_currentUser?.id == id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя менять свою собственную роль')),
      );
      return;
    }

    if (_actionInProgress.contains(id)) return;

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      await _userService.updateUserRole(targetUserId: id, role: nextRole);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Роль изменена на $nextRole')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка смены роли: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(id);
        });
      }
    }
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').trim().toUpperCase()) {
      case 'ADMIN':
        return 'ADMIN';
      case 'MODERATOR':
        return 'MODERATOR';
      default:
        return 'USER';
    }
  }

  String _sanctionLabel(UserSanctionModel sanction) {
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

  Future<void> _openSanctionDialog(_ModerationUserItem item) async {
    final sanction = item.activeSanction;
    if (sanction != null && sanction.isActive) {
      final shouldRevoke = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Отозвать санкцию?'),
          content: Text(
            'Активная санкция: ${_sanctionLabel(sanction)}\n\nПричина: ${sanction.reason}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Отозвать'),
            ),
          ],
        ),
      );

      if (shouldRevoke == true) {
        await _revokeSanction(item, sanction.id);
      }
      return;
    }

    String sanctionType = 'WARNING';
    final reasonController = TextEditingController();
    final daysController = TextEditingController();

    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Назначить санкцию'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: sanctionType,
                    items: const [
                      DropdownMenuItem(value: 'WARNING', child: Text('WARNING')),
                      DropdownMenuItem(value: 'MUTE', child: Text('MUTE')),
                      DropdownMenuItem(value: 'EVENT_CREATE_BAN', child: Text('EVENT_CREATE_BAN')),
                      DropdownMenuItem(value: 'FULL_BAN', child: Text('FULL_BAN')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => sanctionType = value);
                    },
                    decoration: const InputDecoration(labelText: 'Тип санкции'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Причина',
                      hintText: 'Опишите нарушение',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Срок (дней, пусто = бессрочно)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldApply == true) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Укажите причину санкции')),
          );
        }
        reasonController.dispose();
        daysController.dispose();
        return;
      }

      final days = int.tryParse(daysController.text.trim());
      final expiresAt = days != null && days > 0
          ? DateTime.now().toUtc().add(Duration(days: days))
          : null;
      await _applySanction(item, sanctionType, reason, expiresAt);
    }

    reasonController.dispose();
    daysController.dispose();
  }

  Future<void> _applySanction(
    _ModerationUserItem item,
    String type,
    String reason,
    DateTime? expiresAt,
  ) async {
    final id = item.user.id;
    if (_actionInProgress.contains(id)) return;

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      await _userService.createUserSanction(
        targetUserId: id,
        type: type,
        reason: reason,
        expiresAt: expiresAt,
      );

      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция применена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка применения санкции: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(id);
        });
      }
    }
  }

  Future<void> _revokeSanction(_ModerationUserItem item, String sanctionId) async {
    final id = item.user.id;
    if (_actionInProgress.contains(id)) return;

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      await _userService.revokeUserSanction(sanctionId);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция отозвана')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отзыва санкции: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(id);
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

  Future<void> _blockUser(_ModerationUserItem item) async {
    final id = item.user.id;
    if (_actionInProgress.contains(id)) return;

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      await _userService.blockUser(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь заблокирован')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка блокировки: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(id);
        });
      }
    }
  }

  Future<void> _resolvePendingReports(_ModerationUserItem item) async {
    final id = item.user.id;
    if (_actionInProgress.contains(id)) return;

    final pending = item.reports
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У пользователя нет активных жалоб')),
      );
      return;
    }

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      for (final report in pending) {
        await _reportService.resolveReport(report.id, 'RESOLVED');
      }

      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Закрыто жалоб: ${pending.length}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка закрытия жалоб: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress.remove(id);
        });
      }
    }
  }

  Future<void> _showUserReportsDialog(_ModerationUserItem item) async {
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
                      Icons.report_problem_rounded,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Жалобы пользователя',
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
                      'По пользователю пока нет жалоб',
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
                              Text(
                                'ID: ${report.id}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.dark.withValues(alpha: 0.45),
                                ),
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _dismissSingleReport(item, report);
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

  Future<void> _dismissSingleReport(_ModerationUserItem item, ReportModel report) async {
    final id = item.user.id;
    if (_actionInProgress.contains(id)) return;

    setState(() {
      _actionInProgress.add(id);
    });

    try {
      await _reportService.resolveReport(report.id, 'DISMISSED');
      await _loadUsers();
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
          _actionInProgress.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((item) {
      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.user.email.toLowerCase().contains(q) ||
          (item.user.displayName ?? '').toLowerCase().contains(q);
    }).toList();

    return AdminScreenScaffold(
      title: 'Управление пользователями',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadUsers,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Поиск по email или имени',
                prefixIcon: const Icon(Icons.search),
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
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReportsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.report_problem_rounded),
                  label: const Text('Смотреть все жалобы'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dark.withValues(alpha: 0.72),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const AdminStateView.loading()
                : _loadError != null
                    ? AdminStateView.error(
                        title: 'Не удалось загрузить пользователей',
                        message: _loadError,
                        actionLabel: 'Повторить',
                        onAction: _loadUsers,
                      )
                    : filtered.isEmpty
                        ? const AdminStateView.empty(
                            title: 'Пользователи не найдены',
                            message: 'Попробуйте изменить запрос поиска.',
                            icon: Icons.person_search_rounded,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final user = item.user;
                                final inProgress =
                                    _actionInProgress.contains(user.id);

                                return AdminCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                AppColors.accent.withValues(alpha: 0.55),
                                            backgroundImage: user.photoUrl != null
                                                ? NetworkImage(user.photoUrl!)
                                                : null,
                                            child: user.photoUrl == null
                                                ? Text(
                                                    (user.displayName?.isNotEmpty == true
                                                            ? user.displayName!
                                                            : user.email)[0]
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color: AppColors.dark.withValues(alpha: 0.65),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.displayName?.isNotEmpty == true
                                                      ? user.displayName!
                                                      : user.email,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                    height: 1.15,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  user.email,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppColors.dark.withValues(alpha: 0.55),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              AdminPill(
                                                label: '${item.pendingReports}',
                                                backgroundColor: item.pendingReports > 0
                                                    ? const Color(0xFFFFEFE8)
                                                    : const Color(0xFFEAF8F2),
                                                foregroundColor: item.pendingReports > 0
                                                    ? const Color(0xFFD16A3A)
                                                    : const Color(0xFF2E9E71),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                              if (_isAdmin) ...[
                                                const SizedBox(height: 6),
                                                PopupMenuButton<String>(
                                                  enabled: !inProgress,
                                                  onSelected: (role) =>
                                                      _changeUserRole(item, role),
                                                  itemBuilder: (context) => const [
                                                    PopupMenuItem<String>(
                                                      value: 'USER',
                                                      child: Text('Сделать USER'),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'MODERATOR',
                                                      child: Text('Сделать MODERATOR'),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'ADMIN',
                                                      child: Text('Сделать ADMIN'),
                                                    ),
                                                  ],
                                                  child: AdminPill(
                                                    label: _roleLabel(user.role),
                                                    backgroundColor: AppColors.primary
                                                        .withValues(alpha: 0.10),
                                                    foregroundColor: AppColors.primary,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (_isAdmin &&
                                              item.activeSanction != null &&
                                              item.activeSanction!.isActive)
                                            AdminPill(
                                              label: _sanctionLabel(item.activeSanction!),
                                              backgroundColor: const Color(0xFFFFF3E6),
                                              foregroundColor: const Color(0xFFD16A3A),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: inProgress
                                                    ? null
                                                    : () {
                                                        Navigator.of(context).push(
                                                          MaterialPageRoute<void>(
                                                            builder: (_) =>
                                                                UserProfileScreen.fromUser(
                                                              user: user,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.dark.withValues(alpha: 0.72),
                                                  side: BorderSide(
                                                    color: AppColors.primary.withValues(alpha: 0.14),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Профиль',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _showUserReportsDialog(item),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.dark.withValues(alpha: 0.72),
                                                  side: BorderSide(
                                                    color: AppColors.primary.withValues(alpha: 0.14),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Жалобы',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: inProgress
                                                    ? null
                                                    : () => _resolvePendingReports(item),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'Закрыть',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed:
                                                    inProgress ? null : () => _blockUser(item),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFFF6B6B),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'Блок',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_isAdmin) ...[
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 36,
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: inProgress
                                                ? null
                                                : () => _openSanctionDialog(item),
                                            icon: const Icon(Icons.gavel_rounded, size: 18),
                                            label: Text(
                                              item.activeSanction != null &&
                                                      item.activeSanction!.isActive
                                                  ? 'Санкция'
                                                  : 'Назначить санкцию',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.dark.withValues(alpha: 0.72),
                                              side: BorderSide(
                                                color: AppColors.primary.withValues(alpha: 0.14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
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
          ),
        ],
      ),
    );
  }
}

class _ModerationUserItem {
  const _ModerationUserItem({
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
