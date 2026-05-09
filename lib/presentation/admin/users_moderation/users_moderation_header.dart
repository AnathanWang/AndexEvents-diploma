import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../screens/reports_screen.dart';

class UsersModerationHeader extends StatelessWidget {
  const UsersModerationHeader({
    super.key,
    required this.onSearchChanged,
    required this.showReportsShortcut,
  });

  final ValueChanged<String> onSearchChanged;
  final bool showReportsShortcut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: onSearchChanged,
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
        if (showReportsShortcut)
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
      ],
    );
  }
}
