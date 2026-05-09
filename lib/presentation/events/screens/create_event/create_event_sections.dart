import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'create_event_widgets.dart';

class CreateEventIntroCard extends StatelessWidget {
  const CreateEventIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Создайте событие за минуту',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark.withValues(alpha: 0.86),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Заполните основные детали. Фото, место и стоимость можно обновить позже.',
                  style: TextStyle(
                    color: AppColors.dark.withValues(alpha: 0.66),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateEventFormatCard extends StatelessWidget {
  const CreateEventFormatCard({
    super.key,
    required this.isOnline,
    required this.onSetOnline,
  });

  final bool isOnline;
  final ValueChanged<bool> onSetOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Формат события',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.84),
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOnline
                ? 'Онлайн • ссылка/платформа в описании'
                : 'Оффлайн • выберите место на карте',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.60),
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
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
                    label: 'Оффлайн',
                    icon: Icons.place_rounded,
                    isSelected: !isOnline,
                    onTap: () => onSetOnline(false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CreateEventSegmentButton(
                    label: 'Онлайн',
                    icon: Icons.videocam_rounded,
                    isSelected: isOnline,
                    onTap: () => onSetOnline(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

