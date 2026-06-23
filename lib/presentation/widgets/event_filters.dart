import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'event_filters_sheet.dart';

class EventFiltersWidget extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onFiltersChanged;
  final Map<String, dynamic> initialFilters;

  const EventFiltersWidget({
    super.key,
    required this.onFiltersChanged,
    this.initialFilters = const {},
  });

  @override
  State<EventFiltersWidget> createState() => _EventFiltersWidgetState();
}

class _EventFiltersWidgetState extends State<EventFiltersWidget> {
  late String _selectedCategory;
  late String _selectedDate;
  late String _sortBy;
  late String _price;
  late String _format;

  @override
  void initState() {
    super.initState();
    _applyFilters(widget.initialFilters);
  }

  @override
  void didUpdateWidget(covariant EventFiltersWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilters != widget.initialFilters) {
      _applyFilters(widget.initialFilters);
    }
  }

  void _applyFilters(Map<String, dynamic> filters) {
    _selectedCategory = filters['category'] ?? 'all';
    _selectedDate = filters['date'] ?? 'week';
    _sortBy = filters['sort'] ?? 'nearest';
    _price = filters['price'] ?? 'all';
    _format = filters['format'] ?? 'all';
  }

  Map<String, dynamic> _currentFilters() {
    return {
      'category': _selectedCategory,
      'date': _selectedDate,
      'sort': _sortBy,
      'price': _price,
      'format': _format,
    };
  }

  Future<void> _openFiltersSheet() async {
    await showEventFiltersSheet(
      context,
      initialFilters: _currentFilters(),
      onApply: (next) {
        setState(() => _applyFilters(next));
        widget.onFiltersChanged(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = _currentFilters();
    final hasActiveFilters = !eventFiltersAreDefault(filters);
    final activeFiltersCount = eventFiltersActiveCount(filters);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openFiltersSheet,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    color: AppColors.primary.withValues(alpha: 0.86),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Фильтры',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.84, end: 1).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: hasActiveFilters
                        ? Container(
                            key: ValueKey<int>(activeFiltersCount),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$activeFiltersCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey<String>('no-badge')),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    color: AppColors.dark.withValues(alpha: 0.58),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
