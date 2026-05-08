import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/services/rating_service.dart';
import '../../../widgets/common/custom_notification.dart';

class EventDetailRatingDialog extends StatefulWidget {
  const EventDetailRatingDialog({
    super.key,
    required this.event,
    required this.ratingService,
    required this.onRated,
  });

  final EventModel event;
  final RatingService ratingService;
  final ValueChanged<int> onRated;

  @override
  State<EventDetailRatingDialog> createState() => _EventDetailRatingDialogState();
}

class _EventDetailRatingDialogState extends State<EventDetailRatingDialog> {
  int _selectedRating = 5;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.ratingService.rateEvent(
        widget.event.id,
        _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRated(_selectedRating);
      CustomNotification.show(
        context,
        'Спасибо за оценку!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      CustomNotification.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Оцените событие'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Как вам мероприятие?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _selectedRating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ваш комментарий (необязательно)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            enabled: !_isSubmitting,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Отправить'),
        ),
      ],
    );
  }
}

