import '../../../widgets/common/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

typedef SoftDecorationBuilder = InputDecoration Function({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffix,
  bool alignLabelWithHint,
});

class EditEventPhotosSection extends StatelessWidget {
  const EditEventPhotosSection({
    super.key,
    required this.decoration,
    required this.maxPhotos,
    required this.photoUrls,
    required this.pendingUploads,
    required this.isUploading,
    required this.onPickImages,
    required this.onRemovePhoto,
  });

  final Decoration decoration;
  final int maxPhotos;
  final List<String> photoUrls;
  final int pendingUploads;
  final bool isUploading;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final countLabel = '${photoUrls.length}/$maxPhotos';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            icon: Icons.photo_camera_back_rounded,
            title: 'Обложка',
            subtitle: 'До $maxPhotos фото • первое будет главным',
            trailing: Text(
              countLabel,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.dark.withValues(alpha: 0.56),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPickImages,
            child: Container(
              height: 176,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : photoUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(
                            imageUrl: photoUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.broken_image_rounded,
                              size: 30,
                              color: AppColors.dark.withValues(alpha: 0.44),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: AppColors.primary.withValues(alpha: 0.92),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Изменить фото',
                              style: TextStyle(
                                color: AppColors.dark.withValues(alpha: 0.78),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length +
                    (photoUrls.length + pendingUploads < maxPhotos ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == photoUrls.length &&
                      photoUrls.length + pendingUploads < maxPhotos) {
                    return GestureDetector(
                      onTap: onPickImages,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  }

                  final url = photoUrls[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AppNetworkImage(
                          imageUrl: url,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.surface.withValues(alpha: 0.84),
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, _, __) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.surface.withValues(alpha: 0.84),
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.dark.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => onRemovePhoto(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.dark.withValues(alpha: 0.62),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EditEventDetailsSection extends StatelessWidget {
  const EditEventDetailsSection({
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

  final Decoration decoration;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController customCategoryController;
  final List<String> categories;
  final List<String> selectedCategories;
  final ValueChanged<String> onToggleCategory;
  final SoftDecorationBuilder inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.edit_rounded,
            title: 'Описание события',
            subtitle: 'Название, детали и категория',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: titleController,
            decoration: inputDecorationBuilder(
              label: 'Название',
              icon: Icons.title_rounded,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите название';
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
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ...categories.map((c) {
                final selected = selectedCategories.contains(c);
                return FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: customCategoryController,
            style: const TextStyle(fontSize: 13),
            decoration: inputDecorationBuilder(
              label: 'Своя категория',
              hint: 'Например: Псай-транс вечеринка',
              icon: Icons.category_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            maxLines: 4,
            decoration: inputDecorationBuilder(
              label: 'Описание',
              alignLabelWithHint: true,
              hint: 'Расскажите о формате, деталях...',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите описание';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class EditEventScheduleSection extends StatelessWidget {
  const EditEventScheduleSection({
    super.key,
    required this.decoration,
    required this.selectedDate,
    required this.selectedTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.inputDecorationBuilder,
  });

  final Decoration decoration;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final SoftDecorationBuilder inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Когда',
            subtitle: 'Дата и время начала',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: inputDecorationBuilder(
                      label: 'Дата',
                      icon: Icons.calendar_today_rounded,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DateFormat('dd.MM.yyyy').format(selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onPickTime,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: inputDecorationBuilder(
                      label: 'Время',
                      icon: Icons.access_time_rounded,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedTime.format(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditEventLocationPriceSection extends StatelessWidget {
  const EditEventLocationPriceSection({
    super.key,
    required this.decoration,
    required this.isOnline,
    required this.locationController,
    required this.onOpenMapPicker,
    required this.priceController,
    required this.onToggleOnline,
    required this.inputDecorationBuilder,
  });

  final Decoration decoration;
  final bool isOnline;
  final TextEditingController locationController;
  final VoidCallback onOpenMapPicker;
  final TextEditingController priceController;
  final ValueChanged<bool> onToggleOnline;
  final SoftDecorationBuilder inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: isOnline ? Icons.videocam_rounded : Icons.place_rounded,
            title: 'Где и стоимость',
            subtitle: isOnline ? 'Онлайн' : 'Локация и цена',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: locationController,
            readOnly: true,
            onTap: onOpenMapPicker,
            decoration: inputDecorationBuilder(
              label: 'Местоположение',
              hint: 'Выберите место на карте',
              icon: Icons.location_on_rounded,
              suffix: IconButton(
                icon: Icon(
                  Icons.map_rounded,
                  color: AppColors.primary.withValues(alpha: 0.86),
                ),
                onPressed: onOpenMapPicker,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, выберите местоположение';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: SwitchListTile(
              title: Text(
                'Онлайн событие',
                style: TextStyle(
                  color: AppColors.dark.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w800,
                ),
              ),
              value: isOnline,
              activeThumbColor: AppColors.primary,
              onChanged: onToggleOnline,
              secondary:
                  Icon(isOnline ? Icons.videocam_rounded : Icons.people_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: inputDecorationBuilder(
              label: 'Цена (₽)',
              hint: 'Например: 500',
              icon: Icons.payments_rounded,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите цену';
              }
              if (double.tryParse(value) == null) {
                return 'Введите корректное число';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark.withValues(alpha: 0.86),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dark.withValues(alpha: 0.58),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

