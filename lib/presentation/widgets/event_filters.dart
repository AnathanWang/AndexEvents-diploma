import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class EventFiltersWidget extends StatefulWidget {
  final Function(Map<String, dynamic> filters) onFiltersChanged;
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

  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': 'Все'},
    {'value': 'concert', 'label': 'Концерт'},
    {'value': 'sport', 'label': 'Спорт'},
    {'value': 'exhibition', 'label': 'Выставка'},
    {'value': 'conference', 'label': 'Конференция'},
    {'value': 'party', 'label': 'Вечеринка'},
    {'value': 'theater', 'label': 'Театр'},
    {'value': 'cinema', 'label': 'Кино'},
  ];

  final List<Map<String, String>> _dateFilters = [
    {'value': 'all', 'label': 'Все даты'},
    {'value': 'today', 'label': 'Сегодня'},
    {'value': 'week', 'label': 'На неделю'},
    {'value': 'month', 'label': 'На месяц'},
  ];

  final List<Map<String, String>> _sortOptions = [
    {'value': 'nearest', 'label': 'Ближайшие'},
    {'value': 'popular', 'label': 'Популярные'},
    {'value': 'rating', 'label': 'По рейтингу'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilters['category'] ?? 'all';
    _selectedDate = widget.initialFilters['date'] ?? 'week';
    _sortBy = widget.initialFilters['sort'] ?? 'nearest';
  }

  void _notifyFiltersChanged() {
    widget.onFiltersChanged({
      'category': _selectedCategory,
      'date': _selectedDate,
      'sort': _sortBy,
    });
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.surface.withValues(alpha: 0.98),
                      AppColors.accent.withValues(alpha: 0.84),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Фильтры',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark.withValues(alpha: 0.88),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: AppColors.dark.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category filter
                          Text(
                            'Категория',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark.withValues(alpha: 0.84),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _categories.map((category) {
                              final isSelected =
                                  _selectedCategory == category['value'];
                              return FilterChip(
                                label: Text(category['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    _selectedCategory = category['value']!;
                                  });
                                },
                                showCheckmark: false,
                                backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.dark.withValues(alpha: 0.64),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.34)
                                      : AppColors.dark.withValues(alpha: 0.14),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Date filter
                          Text(
                            'Период',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark.withValues(alpha: 0.84),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _dateFilters.map((dateFilter) {
                              final isSelected =
                                  _selectedDate == dateFilter['value'];
                              return FilterChip(
                                label: Text(dateFilter['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    _selectedDate = dateFilter['value']!;
                                  });
                                },
                                showCheckmark: false,
                                backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.dark.withValues(alpha: 0.64),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.34)
                                      : AppColors.dark.withValues(alpha: 0.14),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Sort filter
                          Text(
                            'Сортировка',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark.withValues(alpha: 0.84),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _sortOptions.map((sortOption) {
                              final isSelected = _sortBy == sortOption['value'];
                              return FilterChip(
                                label: Text(sortOption['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    _sortBy = sortOption['value']!;
                                  });
                                },
                                showCheckmark: false,
                                backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.dark.withValues(alpha: 0.64),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.34)
                                      : AppColors.dark.withValues(alpha: 0.14),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _notifyFiltersChanged();
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Применить'),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _selectedCategory != 'all' ||
        _selectedDate != 'week' ||
        _sortBy != 'nearest';
    final int activeFiltersCount =
      (_selectedCategory != 'all' ? 1 : 0) +
      (_selectedDate != 'week' ? 1 : 0) +
      (_sortBy != 'nearest' ? 1 : 0);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showFiltersBottomSheet,
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
                              style: TextStyle(
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
