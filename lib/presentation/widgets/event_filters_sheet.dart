import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Opens the shared event filters bottom sheet (feed, map, search).
Future<void> showEventFiltersSheet(
  BuildContext context, {
  required Map<String, dynamic> initialFilters,
  required ValueChanged<Map<String, dynamic>> onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: _EventFiltersSheet(
            initialFilters: initialFilters,
            onApply: (next) {
              onApply(next);
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      );
    },
  );
}

bool eventFiltersAreDefault(Map<String, dynamic> filters) {
  return (filters['category'] ?? 'all') == 'all' &&
      (filters['date'] ?? 'week') == 'week' &&
      (filters['sort'] ?? 'nearest') == 'nearest' &&
      (filters['price'] ?? 'all') == 'all' &&
      (filters['format'] ?? 'all') == 'all';
}

int eventFiltersActiveCount(Map<String, dynamic> filters) {
  var count = 0;
  if ((filters['category'] ?? 'all') != 'all') count++;
  if ((filters['date'] ?? 'week') != 'week') count++;
  if ((filters['sort'] ?? 'nearest') != 'nearest') count++;
  if ((filters['price'] ?? 'all') != 'all') count++;
  if ((filters['format'] ?? 'all') != 'all') count++;
  return count;
}

class _EventFiltersSheet extends StatefulWidget {
  const _EventFiltersSheet({
    required this.initialFilters,
    required this.onApply,
  });

  final Map<String, dynamic> initialFilters;
  final ValueChanged<Map<String, dynamic>> onApply;

  @override
  State<_EventFiltersSheet> createState() => _EventFiltersSheetState();
}

class _EventFiltersSheetState extends State<_EventFiltersSheet> {
  static const _categories = <Map<String, String>>[
    {'value': 'all', 'label': 'Все'},
    {'value': 'concert', 'label': 'Концерт'},
    {'value': 'sport', 'label': 'Спорт'},
    {'value': 'exhibition', 'label': 'Выставка'},
    {'value': 'conference', 'label': 'Конференция'},
    {'value': 'party', 'label': 'Вечеринка'},
    {'value': 'theater', 'label': 'Театр'},
    {'value': 'cinema', 'label': 'Кино'},
  ];

  static const _dateFilters = <Map<String, String>>[
    {'value': 'all', 'label': 'Все даты'},
    {'value': 'today', 'label': 'Сегодня'},
    {'value': 'week', 'label': 'На неделю'},
    {'value': 'month', 'label': 'На месяц'},
  ];

  static const _sortOptions = <Map<String, String>>[
    {'value': 'nearest', 'label': 'Ближайшие'},
    {'value': 'popular', 'label': 'Популярные'},
    {'value': 'rating', 'label': 'По рейтингу'},
  ];

  static const _priceOptions = <Map<String, String>>[
    {'value': 'all', 'label': 'Любая цена'},
    {'value': 'free', 'label': 'Бесплатно'},
    {'value': 'paid', 'label': 'Платно'},
  ];

  static const _formatOptions = <Map<String, String>>[
    {'value': 'all', 'label': 'Онлайн + офлайн'},
    {'value': 'offline', 'label': 'Офлайн'},
    {'value': 'online', 'label': 'Онлайн'},
  ];

  late String _selectedCategory;
  late String _selectedDate;
  late String _sortBy;
  late String _price;
  late String _format;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilters['category'] ?? 'all';
    _selectedDate = widget.initialFilters['date'] ?? 'week';
    _sortBy = widget.initialFilters['sort'] ?? 'recommended';
    _price = widget.initialFilters['price'] ?? 'all';
    _format = widget.initialFilters['format'] ?? 'all';
  }

  Map<String, dynamic> _buildFilters() {
    return {
      'category': _selectedCategory,
      'date': _selectedDate,
      'sort': _sortBy,
      'price': _price,
      'format': _format,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _FilterSection(
                    title: 'Категория',
                    options: _categories,
                    selected: _selectedCategory,
                    onSelected: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  _FilterSection(
                    title: 'Период',
                    options: _dateFilters,
                    selected: _selectedDate,
                    onSelected: (value) => setState(() => _selectedDate = value),
                  ),
                  _FilterSection(
                    title: 'Сортировка',
                    options: _sortOptions,
                    selected: _sortBy,
                    onSelected: (value) => setState(() => _sortBy = value),
                  ),
                  _FilterSection(
                    title: 'Цена',
                    options: _priceOptions,
                    selected: _price,
                    onSelected: (value) => setState(() => _price = value),
                  ),
                  _FilterSection(
                    title: 'Формат',
                    options: _formatOptions,
                    selected: _format,
                    onSelected: (value) => setState(() => _format = value),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onApply(_buildFilters()),
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
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<Map<String, String>> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark.withValues(alpha: 0.84),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((option) {
              final value = option['value']!;
              final isSelected = selected == value;
              return FilterChip(
                label: Text(option['label']!),
                selected: isSelected,
                onSelected: (_) => onSelected(value),
                showCheckmark: false,
                backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.dark.withValues(alpha: 0.64),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
        ],
      ),
    );
  }
}
