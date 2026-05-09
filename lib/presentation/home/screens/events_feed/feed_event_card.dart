import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../../events/bloc/event_bloc.dart';
import '../../../events/bloc/event_event.dart';
import '../../../events/screens/real_event_detail_screen.dart';
import '../../../widgets/event_countdown_timer.dart';

class FeedEventCard extends StatelessWidget {
  const FeedEventCard({
    super.key,
    required this.event,
    required this.categoryName,
    required this.categoryColor,
  });

  final EventModel event;
  final String categoryName;
  final Color categoryColor;

  String _creatorInitial(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final formattedTime = DateFormat('dd MMM, HH:mm', 'ru').format(
      event.dateTime,
    );

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                BlocProvider(
                  create: (context) => EventBloc(),
                  child: RealEventDetailScreen(eventId: event.id),
                ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final curve = Curves.easeOutCubic;
              final curvedAnimation = curve.transform(animation.value);
              final tween = Tween(begin: begin, end: end);
              final offsetAnimation = tween.animate(
                AlwaysStoppedAnimation(curvedAnimation),
              );

              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 280),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<EventBloc>().add(const EventsLoadRequested());
          }
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.14),
            width: 1,
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: SizedBox(
                height: 158,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (event.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.grey.shade50,
                          child: Container(color: AppColors.surface),
                        ),
                        errorWidget: (context, url, error) {
                          LoggerService.error(
                            'Error loading feed event image: $url, error: $error',
                          );
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  categoryColor.withValues(alpha: 0.45),
                                  categoryColor.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              categoryColor.withValues(alpha: 0.45),
                              categoryColor.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.54),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dark.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formattedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      color: AppColors.dark.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: AppColors.dark.withValues(alpha: 0.62),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (event.ratingCount > 0) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.averageRating.toStringAsFixed(1)} (${event.ratingCount})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          event.participantsCount == 1
                              ? '1 участник'
                              : '${event.participantsCount} участников',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  if (event.creatorName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (event.creatorPhotoUrl != null)
                          CachedNetworkImage(
                            imageUrl: event.creatorPhotoUrl!,
                            imageBuilder: (context, imageProvider) =>
                                CircleAvatar(
                              radius: 13,
                              backgroundImage: imageProvider,
                            ),
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade50,
                              child: const CircleAvatar(
                                radius: 13,
                                backgroundColor: AppColors.surface,
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 13,
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.92),
                              child: Text(
                                _creatorInitial(event.creatorName),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.dark.withValues(alpha: 0.62),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 13,
                            backgroundColor:
                                AppColors.accent.withValues(alpha: 0.92),
                            child: Text(
                              _creatorInitial(event.creatorName),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.dark.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Организатор: ${event.creatorName!}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.dark.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  EventCountdownTimer(
                    expirationTime: event.actualEndDateTime,
                    isMinimal: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

