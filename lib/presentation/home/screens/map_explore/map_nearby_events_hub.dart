import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../../events/bloc/event_bloc.dart';
import '../../../events/screens/real_event_detail_screen.dart';

/// Bottom slot for the nearby-events hub with soft show/hide transitions.
class MapExploreEventsHubSlot extends StatelessWidget {
  const MapExploreEventsHubSlot({
    super.key,
    required this.expanded,
    required this.gestureHidden,
    required this.hubHeight,
    required this.hub,
    required this.collapsedButton,
  });

  static const Duration _hideDuration = Duration(milliseconds: 260);
  static const Duration _showDuration = Duration(milliseconds: 380);

  final bool expanded;
  final bool gestureHidden;
  final double hubHeight;
  final Widget hub;
  final Widget collapsedButton;

  @override
  Widget build(BuildContext context) {
    const collapsedHeight = 42.0;

    return AnimatedSize(
      duration: _showDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: expanded ? hubHeight : collapsedHeight,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            _AnimatedHubLayer(
              visible: expanded && !gestureHidden,
              hideDuration: _hideDuration,
              showDuration: _showDuration,
              hiddenOffset: gestureHidden ? 0.22 : 0.1,
              child: hub,
            ),
            _AnimatedHubLayer(
              visible: !expanded,
              hideDuration: _hideDuration,
              showDuration: _showDuration,
              hiddenOffset: 0.14,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: collapsedButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHubLayer extends StatelessWidget {
  const _AnimatedHubLayer({
    required this.visible,
    required this.hideDuration,
    required this.showDuration,
    required this.hiddenOffset,
    required this.child,
  });

  final bool visible;
  final Duration hideDuration;
  final Duration showDuration;
  final double hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = visible ? showDuration : hideDuration;
    final curve = visible ? Curves.easeOutCubic : Curves.easeInCubic;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: visible ? Curves.easeOut : Curves.easeIn,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(0, hiddenOffset),
          duration: duration,
          curve: curve,
          child: child,
        ),
      ),
    );
  }
}

class MapNearbyEventsHub extends StatelessWidget {
  const MapNearbyEventsHub({
    super.key,
    required this.events,
    required this.searchQuery,
    required this.hubHeight,
    required this.activeIndexListenable,
    required this.onHideHub,
    this.onEventDetailClosed,
  });

  final List<EventModel> events;
  final String searchQuery;
  final double hubHeight;
  final ValueNotifier<int> activeIndexListenable;
  final VoidCallback onHideHub;
  final VoidCallback? onEventDetailClosed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hubHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'События рядом',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark.withValues(alpha: 0.72),
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${events.length}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.dark.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onHideHub();
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.dark.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.chevron_down,
                              size: 16,
                              color: AppColors.dark.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          searchQuery.isNotEmpty
                              ? 'События не найдены'
                              : 'Нет событий рядом',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.dark.withValues(alpha: 0.7),
                              ),
                        ),
                      )
                    : ValueListenableBuilder<int>(
                        valueListenable: activeIndexListenable,
                        builder: (context, activeIndex, _) {
                          final int current = events.isEmpty
                              ? 0
                              : activeIndex.clamp(0, events.length - 1);
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: MapNearbyEventCard(
                              event: events[current],
                              onDetailClosed: onEventDetailClosed,
                            ),
                          );
                        },
                      ),
              ),
              if (events.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: ValueListenableBuilder<int>(
                    valueListenable: activeIndexListenable,
                    builder: (context, activeIndex, _) {
                      final int current = events.isEmpty
                          ? 0
                          : activeIndex.clamp(0, events.length - 1);
                      return _HubPageIndicator(
                        currentIndex: current,
                        totalCount: events.length,
                        onIndexSelected: (index) {
                          activeIndexListenable.value = index;
                        },
                      );
                    },
                  ),
                ),
              if (events.length <= 1) const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class MapExploreShowHubButton extends StatelessWidget {
  const MapExploreShowHubButton({
    super.key,
    required this.onShowHub,
  });

  final VoidCallback onShowHub;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onShowHub();
        },
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                CupertinoIcons.square_list,
                size: 16,
                color: AppColors.primary,
              ),
              SizedBox(width: 6),
              Text(
                'События рядом',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubPageIndicator extends StatelessWidget {
  const _HubPageIndicator({
    required this.currentIndex,
    required this.totalCount,
    required this.onIndexSelected,
  });

  final int currentIndex;
  final int totalCount;
  final ValueChanged<int> onIndexSelected;

  @override
  Widget build(BuildContext context) {
    final int visibleCount = totalCount > 5 ? 5 : totalCount;
    final int startIndex = totalCount > 5
        ? (currentIndex - 2).clamp(0, totalCount - visibleCount)
        : 0;
    final int activeDot = (currentIndex - startIndex).clamp(0, visibleCount - 1);

    const double dotSize = 6;
    const double dotGap = 8;
    const double activeWidth = 16;
    final double rowWidth =
        (visibleCount * dotSize) + ((visibleCount - 1) * dotGap);

    return SizedBox(
      width: rowWidth,
      height: dotSize,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(
              visibleCount,
              (index) {
                final dotIndex = startIndex + index;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onIndexSelected(dotIndex);
                  },
                  child: SizedBox(
                    width: dotSize + 8,
                    height: dotSize + 8,
                    child: Center(
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: AppColors.dark.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: (activeDot * (dotSize + dotGap)) -
                ((activeWidth - dotSize) / 2),
            top: 0,
            child: Container(
              width: activeWidth,
              height: dotSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapNearbyEventCard extends StatelessWidget {
  const MapNearbyEventCard({
    super.key,
    required this.event,
    this.onDetailClosed,
  });

  final EventModel event;
  final VoidCallback? onDetailClosed;

  String _getCategoryName(String category) {
    switch (category) {
      case 'concert':
        return 'Концерт';
      case 'sport':
        return 'Спорт';
      case 'exhibition':
        return 'Выставка';
      case 'conference':
        return 'Конференция';
      case 'party':
        return 'Вечеринка';
      case 'theater':
        return 'Театр';
      case 'cinema':
        return 'Кино';
      case 'other':
        return 'Другое';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'concert':
        return AppColors.primary;
      case 'sport':
        return AppColors.dark;
      case 'exhibition':
        return AppColors.primary;
      case 'conference':
        return AppColors.primary;
      case 'party':
        return AppColors.dark;
      case 'theater':
        return AppColors.primary;
      case 'cinema':
        return AppColors.dark;
      case 'other':
        return AppColors.dark;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);
    final categoryName = _getCategoryName(event.category);
    final formattedTime = DateFormat('d MMM, HH:mm', 'ru').format(event.dateTime);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => BlocProvider(
              create: (context) => EventBloc(),
              child: RealEventDetailScreen(eventId: event.id),
            ),
          ),
        ).then((_) {
          if (!context.mounted) return;
          onDetailClosed?.call();
        });
      },
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.dark.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  width: 104,
                  height: 112,
                  fit: BoxFit.cover,
                  memCacheWidth: 208,
                  memCacheHeight: 224,
                  placeholder: (context, url) => Container(
                    width: 104,
                    height: 112,
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 104,
                      height: 112,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withValues(alpha: 0.3),
                            categoryColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 32,
                          color: AppColors.dark,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 104,
                height: 112,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor.withValues(alpha: 0.3),
                      categoryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (event.ratingCount > 0) ...[
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  event.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(
                          CupertinoIcons.location_solid,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

