import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'create_event_widgets.dart' show CreateEventSegmentButton;
import 'create_event_widgets.dart' show CreateEventSectionHeader;

class CreateEventLocationPriceSection extends StatelessWidget {
  const CreateEventLocationPriceSection({
    super.key,
    required this.decoration,
    required this.isOnline,
    required this.locationController,
    required this.onOpenMapPicker,
    required this.isFree,
    required this.onSetFree,
    required this.priceController,
    required this.inputDecorationBuilder,
  });

  final BoxDecoration decoration;
  final bool isOnline;
  final TextEditingController locationController;
  final VoidCallback onOpenMapPicker;
  final bool isFree;
  final ValueChanged<bool> onSetFree;
  final TextEditingController priceController;
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
          CreateEventSectionHeader(
            icon: isOnline ? Icons.videocam_rounded : Icons.place_rounded,
            title: 'Где и стоимость',
            subtitle: isOnline ? 'Онлайн' : 'Локация и цена',
          ),
          const SizedBox(height: 12),
          if (!isOnline) ...<Widget>[
            TextFormField(
              controller: locationController,
              readOnly: true,
              decoration: inputDecorationBuilder(
                label: 'Место проведения',
                hint: 'Выберите место на карте',
                icon: Icons.location_on_rounded,
                suffix: IconButton(
                  icon: Icon(
                    Icons.map_rounded,
                    color: AppColors.primary.withValues(alpha: 0.86),
                  ),
                  onPressed: onOpenMapPicker,
                ),
                alignLabelWithHint: false,
              ),
              onTap: onOpenMapPicker,
              validator: (String? value) {
                if (!isOnline && (value == null || value.isEmpty)) {
                  return 'Укажите место проведения';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: CreateEventSegmentButton(
                    label: 'Бесплатно',
                    icon: Icons.volunteer_activism_rounded,
                    isSelected: isFree,
                    onTap: () => onSetFree(true),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CreateEventSegmentButton(
                    label: 'Платно',
                    icon: Icons.payments_rounded,
                    isSelected: !isFree,
                    onTap: () => onSetFree(false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: isFree
                ? const SizedBox.shrink()
                : TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: inputDecorationBuilder(
                      label: 'Цена (₽)',
                      hint: 'Например: 500',
                      icon: Icons.payments_rounded,
                      alignLabelWithHint: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

