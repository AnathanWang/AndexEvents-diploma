import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_pill.dart';
import 'event_moderation_item.dart';

class EventModerationEventCard extends StatelessWidget {
  const EventModerationEventCard({
    super.key,
    required this.item,
    required this.inProgress,
    required this.onShowReports,
    required this.onShowSanctions,
    required this.onRejectEvent,
    required this.onDismissPendingReports,
  });

  final EventModerationItem item;
  final bool inProgress;
  final VoidCallback onShowReports;
  final VoidCallback onShowSanctions;
  final VoidCallback onRejectEvent;
  final VoidCallback onDismissPendingReports;

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final lastReport =
        item.reports.isEmpty ? null : item.reports.first;
    final totalReports = item.reports.length;
    final lastReportDate = lastReport == null
        ? null
        : DateFormat('dd.MM.yyyy HH:mm', 'ru').format(lastReport.createdAt);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.report_problem_rounded,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              AdminPill(
                label: 'Жалоб: ${item.pendingReports}',
                backgroundColor: item.pendingReports > 0
                    ? const Color(0xFFFFEFE8)
                    : const Color(0xFFEAF8F2),
                foregroundColor: item.pendingReports > 0
                    ? const Color(0xFFD16A3A)
                    : const Color(0xFF2E9E71),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lastReport != null
                ? 'Последняя жалоба: ${lastReport.reason.displayName}'
                : 'Жалоб на событие нет',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Всего: $totalReports • Последняя: ${lastReportDate ?? '-'}',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (lastReport?.details?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              lastReport!.details!.trim(),
              style: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.70),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Локация: ${event.location}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onShowReports,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.dark.withValues(alpha: 0.72),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Смотреть жалобы',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onShowSanctions,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.dark.withValues(alpha: 0.72),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Санкции',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: inProgress ? null : onRejectEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Удалить событие',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: inProgress ? null : onDismissPendingReports,
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
            child: const Text(
              'Отклонить жалобы',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
