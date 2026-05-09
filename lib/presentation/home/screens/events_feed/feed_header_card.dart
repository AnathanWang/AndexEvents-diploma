import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/event_filters.dart';

class FeedHeaderCard extends StatelessWidget {
  const FeedHeaderCard({
    super.key,
    required this.filteredCount,
    required this.searchController,
    required this.selectedCity,
    required this.onOpenSearch,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onPickCity,
    required this.filters,
    required this.onFiltersChanged,
  });

  final int filteredCount;
  final TextEditingController searchController;
  final String selectedCity;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onPickCity;
  final Map<String, dynamic> filters;
  final ValueChanged<Map<String, dynamic>> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.16),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Афиша города',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark.withValues(alpha: 0.88),
                    height: 1.15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$filteredCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            onTap: onOpenSearch,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Поиск событий...',
              hintStyle: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.52),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.dark.withValues(alpha: 0.6),
                size: 20,
              ),
              suffixIcon: ListenableBuilder(
                listenable: searchController,
                builder: (context, _) {
                  if (searchController.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear),
                    color: AppColors.dark.withValues(alpha: 0.6),
                    onPressed: onClearQuery,
                  );
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 1.2,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.84),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPickCity,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary.withValues(alpha: 0.86),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              selectedCity,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark.withValues(alpha: 0.84),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
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
              const SizedBox(width: 8),
              Expanded(
                child: EventFiltersWidget(
                  initialFilters: filters,
                  onFiltersChanged: onFiltersChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

