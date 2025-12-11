import 'package:flutter/material.dart';

/// Кастомный Dropdown с иконкой и красивым оформлением
class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final IconData? prefixIcon;
  final String? hint;
  final EdgeInsets padding;
  final TextStyle? labelStyle;
  final TextStyle? itemStyle;
  final bool useBottomSheet;
  final bool showBottomSheetCount;

  const CustomDropdown({
    Key? key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.hint,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    this.labelStyle,
    this.itemStyle,
    this.useBottomSheet = false,
    this.showBottomSheetCount = true,
  }) : super(key: key);

  String _labelForItem(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) {
      final data = child.data;
      if (data != null) return data;
    }
    final v = item.value;
    return v?.toString() ?? '';
  }

  Future<void> _openBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: colorScheme.surface,
      showDragHandle: false,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final itemCount = items.length;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.5,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (showBottomSheetCount)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            itemCount.toString(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
                Expanded(
                  child: itemCount == 0
                      ? Center(
                          child: Text(
                            'Пока нет вариантов',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: itemCount,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withOpacity(0.35),
                          ),
                          itemBuilder: (ctx, index) {
                            final item = items[index];
                            final itemValue = item.value;
                            final isSelected = itemValue != null && itemValue == value;

                            return ListTile(
                              onTap: itemValue == null
                                  ? null
                                  : () => Navigator.of(ctx).pop<T>(itemValue),
                              title: Text(
                                _labelForItem(item),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check, color: colorScheme.primary)
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(16);

    if (useBottomSheet) {
      final selectedItem = items.where((i) => i.value == value).toList();
      final selectedText = selectedItem.isNotEmpty ? _labelForItem(selectedItem.first) : null;

      return InkWell(
        borderRadius: borderRadius,
        onTap: () => _openBottomSheet(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: labelStyle,
            hintText: hint,
            contentPadding: padding,
            filled: theme.inputDecorationTheme.filled,
            fillColor: theme.inputDecorationTheme.fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: colorScheme.primary,
                    size: 20,
                  )
                : null,
            suffixIcon: Icon(Icons.expand_more, color: colorScheme.primary),
          ),
          child: Text(
            selectedText ?? hint ?? '',
            style: itemStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: selectedText == null
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      borderRadius: borderRadius,
      elevation: 3,
      itemHeight: 52,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: labelStyle,
        hintText: hint,
        contentPadding: padding,
        filled: theme.inputDecorationTheme.filled,
        fillColor: theme.inputDecorationTheme.fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: colorScheme.primary,
                size: 20,
              )
            : null,
        prefixIconConstraints: prefixIcon != null
            ? const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              )
            : null,
      ),
      isExpanded: true,
      dropdownColor: colorScheme.surface,
      style: itemStyle ??
          theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
      icon: Icon(
        Icons.expand_more,
        color: colorScheme.primary,
      ),
    );
  }
}
