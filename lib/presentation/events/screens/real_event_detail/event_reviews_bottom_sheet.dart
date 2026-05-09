import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/models/event_review_model.dart';
import '../../../../data/services/rating_service.dart';
import '../../../widgets/common/star_rating_widget.dart';

const Color _secondaryTextColor = Color(0xFF5E6D86);

class EventReviewsBottomSheet extends StatefulWidget {
  const EventReviewsBottomSheet({
    super.key,
    required this.event,
    required this.ratingService,
  });

  final EventModel event;
  final RatingService ratingService;

  @override
  State<EventReviewsBottomSheet> createState() => _EventReviewsBottomSheetState();
}

class _EventReviewsBottomSheetState extends State<EventReviewsBottomSheet> {
  late Future<List<EventReviewModel>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = widget.ratingService.getEventReviews(widget.event.id);
  }

  void _reload() {
    setState(() {
      _reviewsFuture = widget.ratingService.getEventReviews(widget.event.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCED8F5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Отзывы и оценки',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF243252),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _secondaryTextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ReviewsSummaryCard(event: event),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<EventReviewModel>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Не удалось загрузить отзывы',
                              style: TextStyle(
                                color: AppColors.dark.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _reload,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final reviews = snapshot.data ?? <EventReviewModel>[];
                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 52,
                            color: _secondaryTextColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Пока нет отзывов',
                            style: TextStyle(
                              color: _secondaryTextColor.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _ReviewTile(review: reviews[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSummaryCard extends StatelessWidget {
  const _ReviewsSummaryCard({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E9FF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.ratingCount} оценок',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRatingWidget(
                  rating: event.averageRating,
                  starSize: 18,
                ),
                const SizedBox(height: 6),
                Text(
                  event.ratingCount == 0
                      ? 'Событие без оценок'
                      : 'Средняя оценка участников',
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor.withValues(alpha: 0.9),
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

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final EventReviewModel review;

  @override
  Widget build(BuildContext context) {
    final name =
        review.userName.trim().isNotEmpty ? review.userName.trim() : 'Пользователь';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                child: Text(
                  _reviewInitials(name),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatReviewDate(review.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  '${review.rating} ★',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.dark.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _reviewInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final initials = parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join();
  return initials.isEmpty ? '??' : initials.toUpperCase();
}

String _formatReviewDate(DateTime date) {
  final local = date.toLocal();
  return DateFormat('dd.MM.yyyy HH:mm', 'ru').format(local);
}

