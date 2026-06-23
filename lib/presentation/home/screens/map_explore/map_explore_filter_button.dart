import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/event_filters.dart';

class MapExploreFilterButton extends StatelessWidget {
  const MapExploreFilterButton({
    super.key,
    required this.top,
    required this.horizontalInset,
    required this.filters,
    required this.onFiltersChanged,
  });

  final double top;
  final double horizontalInset;
  final Map<String, dynamic> filters;
  final ValueChanged<Map<String, dynamic>> onFiltersChanged;

  bool get _hasActiveFilters {
    return filters['category'] != 'all' ||
        filters['date'] != 'week' ||
        filters['sort'] != 'nearest' ||
        filters['price'] != 'all' ||
        filters['format'] != 'all';
  }

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.dark.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          EventFiltersWidget(
                            initialFilters: filters,
                            onFiltersChanged: (next) {
                              onFiltersChanged(next);
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: horizontalInset,
      child: Material(
        color: _hasActiveFilters
            ? AppColors.primary.withValues(alpha: 0.92)
            : AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openFilters(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 18,
                  color:
                      _hasActiveFilters ? AppColors.accent : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        _hasActiveFilters ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
