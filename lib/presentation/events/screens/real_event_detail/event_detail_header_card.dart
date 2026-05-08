import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../../widgets/common/star_rating_widget.dart';
import 'real_event_detail_widgets.dart';

class EventDetailHeaderCard extends StatelessWidget {
  const EventDetailHeaderCard({
    super.key,
    required this.event,
    required this.categoryName,
    required this.categoryColor,
    required this.showCreatorReviewButton,
    required this.showManageButton,
    required this.onOpenReviews,
    required this.onOpenMatches,
    required this.onOpenManage,
  });

  final EventModel event;
  final String categoryName;
  final Color categoryColor;
  final bool showCreatorReviewButton;
  final bool showManageButton;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: EventDetailSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryPill(
                  text: categoryName,
                  color: categoryColor,
                ),
                const Spacer(),
                _PricePill(price: event.price),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F3552),
              ),
            ),
            if (event.ratingCount > 0 || showCreatorReviewButton)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (event.ratingCount > 0) ...[
                      StarRatingWidget(
                        rating: event.averageRating,
                        starSize: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${event.averageRating.toStringAsFixed(1)} (${event.ratingCount})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F3552).withValues(alpha: 0.6),
                        ),
                      ),
                    ] else
                      Text(
                        'Пока нет оценок',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F3552).withValues(alpha: 0.5),
                        ),
                      ),
                    const Spacer(),
                    if (showCreatorReviewButton)
                      TextButton.icon(
                        onPressed: onOpenReviews,
                        icon: const Icon(Icons.rate_review_rounded, size: 16),
                        label: const Text('Отзывы'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PillButton(
                  label: 'Метчи',
                  fg: categoryColor,
                  bg: categoryColor.withValues(alpha: 0.10),
                  border: categoryColor.withValues(alpha: 0.22),
                  onTap: onOpenMatches,
                ),
                if (showManageButton) ...[
                  const SizedBox(width: 8),
                  _PillButton(
                    label: 'Управление',
                    fg: Colors.white,
                    bg: AppColors.primary.withValues(alpha: 0.92),
                    border: Colors.transparent,
                    onTap: onOpenManage,
                    fontWeight: FontWeight.w800,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.26),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    final isFree = price == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFree ? const Color(0xFFE5F7EF) : const Color(0xFFFFF0DB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isFree ? const Color(0xFFBEE8D1) : const Color(0xFFF6D3A3),
        ),
      ),
      child: Text(
        isFree ? 'Бесплатно' : '${price.toStringAsFixed(0)} ₽',
        style: TextStyle(
          color: isFree ? Colors.green : Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    required this.onTap,
    this.fontWeight = FontWeight.w700,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final VoidCallback onTap;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

