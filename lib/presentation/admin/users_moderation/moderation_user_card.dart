import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_pill.dart';
import 'moderation_user_item.dart';

class ModerationUserCard extends StatelessWidget {
  const ModerationUserCard({
    super.key,
    required this.item,
    required this.isAdmin,
    required this.inProgress,
    required this.onChangeRole,
    required this.onProfile,
    required this.onReports,
    required this.onResolvePending,
    required this.onBlock,
    required this.onSanction,
  });

  final ModerationUserItem item;
  final bool isAdmin;
  final bool inProgress;
  final ValueChanged<String> onChangeRole;
  final VoidCallback onProfile;
  final VoidCallback onReports;
  final VoidCallback onResolvePending;
  final VoidCallback onBlock;
  final VoidCallback onSanction;

  @override
  Widget build(BuildContext context) {
    final user = item.user;

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
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
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
                  if (isAdmin) ...[
                    const SizedBox(height: 6),
                    PopupMenuButton<String>(
                      enabled: !inProgress,
                      onSelected: onChangeRole,
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
                        label: moderationRolePillLabel(user.role),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.10),
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
              if (isAdmin &&
                  item.activeSanction != null &&
                  item.activeSanction!.isActive)
                AdminPill(
                  label: moderationSanctionPillLabel(item.activeSanction!),
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
                    onPressed: inProgress ? null : onProfile,
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
                    onPressed: onReports,
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
                    onPressed: inProgress ? null : onResolvePending,
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
                    onPressed: inProgress ? null : onBlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
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
          if (isAdmin) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: inProgress ? null : onSanction,
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
  }
}
