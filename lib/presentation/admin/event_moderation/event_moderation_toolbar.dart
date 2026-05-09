import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/admin_card.dart';
import '../widgets/moderation_toggle_chip.dart';

class EventModerationToolbar extends StatelessWidget {
  const EventModerationToolbar({
    super.key,
    required this.onQueryChanged,
    required this.pendingOnly,
    required this.onSelectAll,
    required this.onSelectPendingOnly,
    required this.filteredCount,
    required this.totalCount,
  });

  final ValueChanged<String> onQueryChanged;
  final bool pendingOnly;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectPendingOnly;
  final int filteredCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText:
                  'Поиск: title / eventId / reporterId / reportId',
              prefixIcon: const Icon(Icons.search_rounded),
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
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ModerationToggleChip(
                  label: 'Все',
                  selected: !pendingOnly,
                  onTap: onSelectAll,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ModerationToggleChip(
                  label: 'Только pending',
                  selected: pendingOnly,
                  onTap: onSelectPendingOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Показано: $filteredCount из $totalCount',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
