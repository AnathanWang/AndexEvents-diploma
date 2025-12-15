import 'package:flutter/material.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Фильтры',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category filter
                          Text(
                            'Категория',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A4D6A),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                backgroundColor: Colors.transparent,
                                selectedColor: const Color(
                                  0xFF5E60CE,
                                ).withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : const Color(0xFF9E9E9E),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Date filter
                          Text(
                            'Период',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A4D6A),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                backgroundColor: Colors.transparent,
                                selectedColor: const Color(
                                  0xFF5E60CE,
                                ).withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : const Color(0xFF9E9E9E),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Sort filter
                          Text(
                            'Сортировка',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A4D6A),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                backgroundColor: Colors.transparent,
                                selectedColor: const Color(
                                  0xFF5E60CE,
                                ).withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : const Color(0xFF9E9E9E),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF5E60CE)
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _notifyFiltersChanged();
                          Navigator.pop(context);
                        },
                        child: const Text('Применить'),
                      ),
                    ),
                  ),
                ],
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

    return GestureDetector(
      onTap: _showFiltersBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, color: Color(0xFF5E60CE), size: 18),
            const SizedBox(width: 8),
            const Text(
              'Фильтры',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4D6A),
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E60CE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚙️',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Color(0xFF9E9E9E), size: 18),
          ],
        ),
      ),
    );
  }
}
