import 'package:flutter/material.dart';

import '../../../data/models/report_model.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/report_service.dart';
import '../../../data/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../users_moderation/moderation_user_card.dart';
import '../users_moderation/moderation_user_item.dart';
import '../users_moderation/users_moderation_header.dart';
import '../widgets/admin_screen_scaffold.dart';
import '../widgets/admin_state_view.dart';
import '../widgets/moderation_reports_bottom_sheet.dart';

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
  List<ModerationUserItem> _users = <ModerationUserItem>[];

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

            return ModerationUserItem(
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

  Future<void> _changeUserRole(ModerationUserItem item, String nextRole) async {
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

  Future<void> _openSanctionDialog(ModerationUserItem item) async {
    final sanction = item.activeSanction;
    if (sanction != null && sanction.isActive) {
      final shouldRevoke = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Отозвать санкцию?'),
          content: Text(
            'Активная санкция: ${moderationSanctionPillLabel(sanction)}\n\nПричина: ${sanction.reason}',
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
    ModerationUserItem item,
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

  Future<void> _revokeSanction(ModerationUserItem item, String sanctionId) async {
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

  Future<void> _blockUser(ModerationUserItem item) async {
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

  Future<void> _resolvePendingReports(ModerationUserItem item) async {
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

  Future<void> _showUserReportsDialog(ModerationUserItem item) async {
    await ModerationReportsBottomSheet.show(
      context: context,
      title: 'Жалобы пользователя',
      headerIcon: Icons.report_problem_rounded,
      reports: item.reports,
      pendingCount: item.pendingReports,
      emptyMessage: 'По пользователю пока нет жалоб',
      showReporterLine: false,
      enableCopyReportIdOnLongPress: false,
      onDismissPendingReport: (report) => _dismissSingleReport(item, report),
    );
  }

  Future<void> _dismissSingleReport(
    ModerationUserItem item,
    ReportModel report,
  ) async {
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
          UsersModerationHeader(
            onSearchChanged: (value) => setState(() => _search = value),
            showReportsShortcut: _isAdmin,
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
                                final inProgress =
                                    _actionInProgress.contains(item.user.id);

                                return ModerationUserCard(
                                  item: item,
                                  isAdmin: _isAdmin,
                                  inProgress: inProgress,
                                  onChangeRole: (role) =>
                                      _changeUserRole(item, role),
                                  onProfile: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            UserProfileScreen.fromUser(
                                          user: item.user,
                                        ),
                                      ),
                                    );
                                  },
                                  onReports: () =>
                                      _showUserReportsDialog(item),
                                  onResolvePending: () =>
                                      _resolvePendingReports(item),
                                  onBlock: () => _blockUser(item),
                                  onSanction: () =>
                                      _openSanctionDialog(item),
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
