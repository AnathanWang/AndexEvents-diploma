import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/report_model.dart';
import 'admin_card.dart';
import 'admin_pill.dart';

class ModerationReportsBottomSheet {
  ModerationReportsBottomSheet._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required IconData headerIcon,
    required List<ReportModel> reports,
    required int pendingCount,
    required ValueChanged<ReportModel> onDismissPendingReport,
    String emptyMessage = 'Записей нет',
    bool showReporterLine = true,
    bool enableCopyReportIdOnLongPress = true,
  }) {
    final sorted = [...reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return showModalBottomSheet<void>(
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
                      headerIcon,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AdminPill(
                      label: '$pendingCount pending',
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      foregroundColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final report = sorted[index];
                        final isPending =
                            report.status.toUpperCase() == 'PENDING';
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
                                      reportReasonDisplayName(report.reason),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
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
                                DateFormat(
                                  'dd.MM.yyyy HH:mm',
                                  'ru',
                                ).format(report.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dark.withValues(alpha: 0.60),
                                ),
                              ),
                              if (showReporterLine) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'От: ${report.reporterId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.dark.withValues(alpha: 0.60),
                                  ),
                                ),
                              ],
                              if ((report.details ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  report.details!.trim(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.dark.withValues(alpha: 0.78),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              enableCopyReportIdOnLongPress
                                  ? GestureDetector(
                                      onLongPress: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: report.id),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('ID жалобы скопирован'),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'ID: ${report.id}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.dark
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'ID: ${report.id}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.dark
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                              if (isPending) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onDismissPendingReport(report);
                                    },
                                    icon:
                                        const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Отклонить эту жалобу'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.dark
                                          .withValues(alpha: 0.70),
                                      side: BorderSide(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.14),
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
}
