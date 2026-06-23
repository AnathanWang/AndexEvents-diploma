import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/event_filters_sheet.dart';

/// Compact filter trigger for the map top bar (no [Positioned] — parent lays out).
class MapExploreFilterButton extends StatelessWidget {
  const MapExploreFilterButton({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  final Map<String, dynamic> filters;
  final ValueChanged<Map<String, dynamic>> onFiltersChanged;

  Future<void> _openFilters(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showEventFiltersSheet(
      context,
      initialFilters: filters,
      onApply: onFiltersChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = !eventFiltersAreDefault(filters);
    final activeCount = eventFiltersActiveCount(filters);

    return Material(
      color: hasActive
          ? AppColors.primary.withValues(alpha: 0.92)
          : AppColors.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: AppColors.dark.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openFilters(context),
        child: SizedBox(
          height: 52,
          width: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 22,
                color: hasActive ? AppColors.accent : AppColors.primary,
              ),
              if (hasActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
