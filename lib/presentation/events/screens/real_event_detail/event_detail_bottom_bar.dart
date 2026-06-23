import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/event_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import 'real_event_detail_widgets.dart';

class EventDetailBottomBar extends StatelessWidget {
  const EventDetailBottomBar({
    super.key,
    required this.event,
    required this.isEventFinished,
    required this.categoryColor,
    required this.isGoing,
    required this.isGoingLoading,
    required this.myRating,
    required this.onToggleGoing,
    required this.onRate,
    this.showCheckInButton = false,
    this.isCheckedIn,
    this.isCheckInLoading,
    this.onToggleCheckIn,
  });

  final EventModel event;
  final bool isEventFinished;
  final Color categoryColor;
  final ValueListenable<bool> isGoing;
  final ValueListenable<bool> isGoingLoading;
  final ValueListenable<int?> myRating;
  final VoidCallback onToggleGoing;
  final VoidCallback onRate;
  final bool showCheckInButton;
  final ValueListenable<bool>? isCheckedIn;
  final ValueListenable<bool>? isCheckInLoading;
  final VoidCallback? onToggleCheckIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EventDetailFloatingActionPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheckInButton &&
                isCheckedIn != null &&
                isCheckInLoading != null &&
                onToggleCheckIn != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckInButton(
                  isCheckedIn: isCheckedIn!,
                  isLoading: isCheckInLoading!,
                  onToggle: onToggleCheckIn!,
                ),
              ),
            _ParticipationButton(
              event: event,
              isEventFinished: isEventFinished,
              categoryColor: categoryColor,
              isGoing: isGoing,
              isGoingLoading: isGoingLoading,
              myRating: myRating,
              onToggleGoing: onToggleGoing,
              onRate: onRate,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({
    required this.isCheckedIn,
    required this.isLoading,
    required this.onToggle,
  });

  final ValueListenable<bool> isCheckedIn;
  final ValueListenable<bool> isLoading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (context, loading, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isCheckedIn,
          builder: (context, checkedIn, __) {
            final Color background = checkedIn
                ? const Color(0xFF00C853).withValues(alpha: 0.92)
                : const Color(0xFF9C5CFF).withValues(alpha: 0.92);
            final Color border = checkedIn
                ? const Color(0xFF00E676).withValues(alpha: 0.6)
                : const Color(0xFFE1B7FF).withValues(alpha: 0.7);

            return Container(
              height: 46,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: loading ? null : onToggle,
                  borderRadius: BorderRadius.circular(18),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                checkedIn
                                    ? Icons.verified_rounded
                                    : Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                checkedIn ? 'Вы здесь' : 'Чек-ин',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ParticipationButton extends StatelessWidget {
  const _ParticipationButton({
    required this.event,
    required this.isEventFinished,
    required this.categoryColor,
    required this.isGoing,
    required this.isGoingLoading,
    required this.myRating,
    required this.onToggleGoing,
    required this.onRate,
  });

  final EventModel event;
  final bool isEventFinished;
  final Color categoryColor;
  final ValueListenable<bool> isGoing;
  final ValueListenable<bool> isGoingLoading;
  final ValueListenable<int?> myRating;
  final VoidCallback onToggleGoing;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isGoingLoading,
      builder: (context, loading, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isGoing,
          builder: (context, going, __) {
            return ValueListenableBuilder<int?>(
              valueListenable: myRating,
              builder: (context, rating, ___) {
                final canRate =
                    isEventFinished && event.isParticipating && rating == null;

                String label;
                if (isEventFinished) {
                  if (event.isParticipating) {
                    label = rating == null ? 'Оценить событие' : 'Ваша оценка: $rating ★';
                  } else {
                    label = EventMessages.eventFinishedButtonTitle;
                  }
                } else {
                  label = going ? 'Отменить участие' : 'Участвовать';
                }

                final bool isActionDisabled =
                    isEventFinished && (!event.isParticipating || rating != null);
                final bool disabled = loading || isActionDisabled;

                Color foreground;
                Color background;
                Color border;

                if (disabled) {
                  foreground = Colors.white.withValues(alpha: 0.86);
                  background = AppColors.dark.withValues(alpha: 0.35);
                  border = Colors.white.withValues(alpha: 0.12);
                } else if (canRate) {
                  foreground = Colors.white;
                  background = const Color(0xFF00C853).withValues(alpha: 0.92);
                  border = const Color(0xFF00E676).withValues(alpha: 0.6);
                } else if (going) {
                  foreground = AppColors.dark;
                  background = AppColors.surface.withValues(alpha: 0.9);
                  border = AppColors.primary.withValues(alpha: 0.18);
                } else {
                  foreground = Colors.white;
                  background = AppColors.primary.withValues(alpha: 0.92);
                  border = AppColors.accent.withValues(alpha: 0.6);
                }

                VoidCallback? onTap;
                if (!loading) {
                  if (isEventFinished) {
                    if (canRate) onTap = onRate;
                  } else {
                    onTap = onToggleGoing;
                  }
                }

                return Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dark.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(18),
                      child: Center(
                        child: loading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    foreground.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            : Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
