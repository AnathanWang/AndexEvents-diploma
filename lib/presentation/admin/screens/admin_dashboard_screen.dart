import 'package:flutter/material.dart';
import 'package:andexevents/presentation/admin/screens/admin_audit_logs_screen.dart';
import 'package:andexevents/presentation/admin/screens/reports_screen.dart';
import 'package:andexevents/presentation/admin/screens/users_list_screen.dart';
import 'package:andexevents/presentation/admin/screens/event_moderation_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    this.showBackButton = true,
    this.onLogout,
    this.headerSubtitle,
    required this.userRole,
  });

  final bool showBackButton;
  final VoidCallback? onLogout;
  final String? headerSubtitle;
  final String userRole;

  bool get _isAdmin => userRole.trim().toUpperCase() == 'ADMIN';
  bool get _isModerator => userRole.trim().toUpperCase() == 'MODERATOR';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1F3FF), Color(0xFFF8FAFF)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x405E60CE), Color(0x109370DB)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x184ECDC4), Color(0x1044A08D)],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: const Color(0xFF5E60CE),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF5965D8), Color(0xFF7D6EEC)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 86, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isAdmin
                                    ? 'Панель администратора'
                                    : 'Панель модератора',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (headerSubtitle != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                headerSubtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF1F4FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            _isAdmin
                                ? 'Полный доступ: события, жалобы и управление пользователями.'
                                : 'Доступ модератора: события и жалобы на события.',
                            style: const TextStyle(
                              color: Color(0xFFE4E9FF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: showBackButton
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF5E60CE),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      )
                    : null,
                actions: [
                  if (onLogout != null)
                    IconButton(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Выйти',
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Инструменты',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F355E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildActionCard(
                      context,
                      title: 'Модерация событий',
                      subtitle: 'Проверка и отклонение проблемных мероприятий',
                      icon: Icons.event_available_rounded,
                      gradientColors: const [
                        Color(0xFF5E60CE),
                        Color(0xFF7D6EEC),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EventModerationScreen(),
                        ),
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(height: 14),
                      _buildActionCard(
                        context,
                        title: 'Жалобы и отчёты',
                        subtitle: 'Обработка всех репортов и решений по ним',
                        icon: Icons.report_problem_rounded,
                        gradientColors: const [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildActionCard(
                        context,
                        title: 'Управление пользователями',
                        subtitle:
                            'Просмотр профилей, блокировки и админ-модерация',
                        icon: Icons.people_rounded,
                        gradientColors: const [
                          Color(0xFF4ECDC4),
                          Color(0xFF44A08D),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersListScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildActionCard(
                        context,
                        title: 'Журнал действий',
                        subtitle: 'Аудит изменений ролей и админ-операций',
                        icon: Icons.fact_check_rounded,
                        gradientColors: const [
                          Color(0xFF5965D8),
                          Color(0xFF4ECDC4),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminAuditLogsScreen(),
                          ),
                        ),
                      ),
                    ] else if (_isModerator) ...[
                      const SizedBox(height: 14),
                      _buildActionCard(
                        context,
                        title: 'Жалобы на события',
                        subtitle:
                            'Просмотр и обработка репортов, связанных с событиями',
                        icon: Icons.flag_rounded,
                        gradientColors: const [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EventModerationScreen(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCE2FF)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F355E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7D85B0),
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF6974BB),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
