import 'package:flutter/material.dart';

import '../../../data/models/report_model.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/report_service.dart';
import '../../../data/services/user_service.dart';
import '../../profile/screens/user_profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((item) {
      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.user.email.toLowerCase().contains(q) ||
          (item.user.displayName ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2F355E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE3FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE3FF)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
                            onPressed: _loadUsers,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Пользователи для модерации не найдены',
                      style: TextStyle(color: Color(0xFF7D85B0)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final user = item.user;
                        final inProgress = _actionInProgress.contains(user.id);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE3FF)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFEAF0FF),
                                    backgroundImage: user.photoUrl != null
                                        ? NetworkImage(user.photoUrl!)
                                        : null,
                                    child: user.photoUrl == null
                                        ? Text(
                                            (user.displayName?.isNotEmpty ==
                                                        true
                                                    ? user.displayName!
                                                    : user.email)[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF5965D8),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName?.isNotEmpty == true
                                              ? user.displayName!
                                              : user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2F355E),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF7A82AC),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
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
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 8),
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
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF2FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _roleLabel(user.role),
                                          style: const TextStyle(
                                            color: Color(0xFF5965D8),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (item.activeSanction != null &&
                                        item.activeSanction!.isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E6),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _sanctionLabel(item.activeSanction!),
                                          style: const TextStyle(
                                            color: Color(0xFFD16A3A),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
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
                                      child: const Text('Профиль'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: inProgress
                                          ? null
                                          : () => _resolvePendingReports(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4ECDC4,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Закрыть жалобы'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: inProgress
                                          ? null
                                          : () => _blockUser(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6B6B,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Блок'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: inProgress
                                        ? null
                                        : () => _openSanctionDialog(item),
                                    icon: const Icon(Icons.gavel_rounded),
                                    label: Text(
                                      item.activeSanction != null &&
                                              item.activeSanction!.isActive
                                          ? 'Управление санкцией'
                                          : 'Назначить санкцию',
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
