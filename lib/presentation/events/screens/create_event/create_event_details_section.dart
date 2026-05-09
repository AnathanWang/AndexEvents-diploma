import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'create_event_widgets.dart';

class CreateEventDetailsSection extends StatelessWidget {
  const CreateEventDetailsSection({
    super.key,
    required this.decoration,
    required this.titleController,
    required this.descriptionController,
    required this.customCategoryController,
    required this.categories,
    required this.selectedCategories,
    required this.onToggleCategory,
    required this.inputDecorationBuilder,
  });

  final BoxDecoration decoration;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController customCategoryController;
  final List<String> categories;
  final List<String> selectedCategories;
  final ValueChanged<String> onToggleCategory;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
    bool alignLabelWithHint,
  }) inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CreateEventSectionHeader(
            icon: Icons.edit_rounded,
            title: 'Описание события',
            subtitle: 'Название, детали и категория',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: titleController,
            decoration: inputDecorationBuilder(
              label: 'Название',
              hint: 'Например: Йога в парке',
              icon: Icons.event_rounded,
              alignLabelWithHint: false,
            ),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Введите название события';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            maxLines: 4,
            decoration: inputDecorationBuilder(
              label: 'Описание',
              hint: 'Расскажите о формате, кому подойдёт, что взять с собой…',
              icon: Icons.notes_rounded,
              alignLabelWithHint: true,
            ),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Введите описание события';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Категория',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.dark.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.map((c) {
              final selected = selectedCategories.contains(c);
              return FilterChip(
                label: Text(
                  c,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selected,
                onSelected: (_) => onToggleCategory(c),
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                backgroundColor: AppColors.surface.withValues(alpha: 0.62),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.34)
                      : AppColors.primary.withValues(alpha: 0.14),
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primary
                      : AppColors.dark.withValues(alpha: 0.78),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: customCategoryController,
            style: const TextStyle(fontSize: 13),
            decoration: inputDecorationBuilder(
              label: 'Своя категория',
              hint: 'Например: Псай-транс вечеринка',
              icon: Icons.category_rounded,
              alignLabelWithHint: false,
            ),
          ),
        ],
      ),
    );
  }
}

