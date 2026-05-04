import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../widgets/yandex_map_widget.dart';
import '../../../data/models/event_model.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/search_screen.dart';
import 'package:andexevents/presentation/widgets/event_countdown_timer.dart';

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}
class _MapExploreScreenState extends State<MapExploreScreen> {
  late TextEditingController _searchController;
  YandexMapController? _mapController;
  Point? _currentUserLocation;
  final ValueNotifier<int> _activeEventIndexNotifier = ValueNotifier<int>(0);
  List<EventModel> _filteredEvents = [];
  bool _isEventsHubHidden = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    context.read<EventBloc>().add(const EventsLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _activeEventIndexNotifier.dispose();
    super.dispose();
  }

  void _filterEvents(List<EventModel> events, String query) {
    if (query.isEmpty) {
      _filteredEvents = events;
    } else {
      _filteredEvents = events
          .where(
            (event) =>
                event.title.toLowerCase().contains(query.toLowerCase()) ||
                event.description.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  void _centerOnUserLocation() {
    if (_mapController != null && _currentUserLocation != null) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentUserLocation!, zoom: 14),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.5,
        ),
      );
    }
  }

  void _focusOnEvent(EventModel event) {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: event.latitude, longitude: event.longitude),
          zoom: 14,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.35,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventBloc, EventState>(
      builder: (context, state) {
        if (state is EventsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = state is EventsLoaded ? state.events : <EventModel>[];

        // Фильтруем события при загрузке
        if (_searchController.text.isEmpty) {
          _filteredEvents = events;
        }

        final double screenWidth = MediaQuery.sizeOf(context).width;
        final double bottomSafeInset = MediaQuery.paddingOf(context).bottom;
        final bool isCompact = screenWidth < 360;
        final double navHorizontalInset = screenWidth >= 430
          ? 52
          : screenWidth >= 390
            ? 44
            : isCompact
              ? 18
              : 30;
        final double eventsHubHorizontalInset = isCompact ? 8 : 12;
        final double navOverlayClearance = bottomSafeInset + 94;
        final double eventsHubHeight = isCompact ? 184 : 204;
        final double eventsHubBottom = navOverlayClearance;
        final double controlsBottom = _isEventsHubHidden
          ? navOverlayClearance + 12
          : eventsHubBottom + eventsHubHeight + 12;

        return Stack(
          children: [
            // Full screen map
            YandexMapWidget(
              events: events,
              isInteractive: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onUserLocationUpdated: (location) {
                _currentUserLocation = location;
              },
              onEventMarkerTapped: (event) {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => EventBloc(),
                      child: RealEventDetailScreen(eventId: event.id),
                    ),
                  ),
                ).then((_) {
                  if (!mounted || !context.mounted) return;
                  context.read<EventBloc>().add(const EventsLoadRequested());
                });
              },
            ),

            // Search bar at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: navHorizontalInset,
              right: navHorizontalInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.dark.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => BlocProvider(
                                  create: (context) => EventBloc(),
                                  child: SearchScreen(
                                    initialQuery: _searchController.text,
                                  ),
                                ),
                              ),
                            );
                          },
                          onChanged: (query) {
                            setState(() {
                              _filterEvents(events, query);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Поиск по карте',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(CupertinoIcons.clear_circled_solid),
                                    color: AppColors.primary,
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterEvents(events, '');
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide.none,
                            ),
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map control buttons (bottom right)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: controlsBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: AppColors.accent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _centerOnUserLocation();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.accent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _mapController?.moveCamera(
                          CameraUpdate.zoomIn(),
                          animation: const MapAnimation(
                            type: MapAnimationType.smooth,
                            duration: 0.3,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.plus,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.accent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _mapController?.moveCamera(
                          CameraUpdate.zoomOut(),
                          animation: const MapAnimation(
                            type: MapAnimationType.smooth,
                            duration: 0.3,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.minus,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!_isEventsHubHidden)
              Positioned(
                left: eventsHubHorizontalInset,
                right: eventsHubHorizontalInset,
                bottom: eventsHubBottom,
                child: _buildNearbyEventsHub(
                  context,
                  events: _filteredEvents,
                  hubHeight: eventsHubHeight,
                ),
              ),

            if (_isEventsHubHidden)
              Positioned(
                left: eventsHubHorizontalInset,
                bottom: eventsHubBottom + 8,
                child: _buildShowHubButton(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNearbyEventsHub(
    BuildContext context, {
    required List<EventModel> events,
    required double hubHeight,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: hubHeight,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
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
                            setState(() {
                              _isEventsHubHidden = true;
                            });
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
                child:
                    events.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? 'События не найдены'
                                  : 'Нет событий рядом',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.dark.withValues(alpha: 0.7)),
                            ),
                          )
                        : PageView.builder(
                            itemCount: events.length,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (index) {
                              _activeEventIndexNotifier.value = index;
                              _focusOnEvent(events[index]);
                            },
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                                child: _buildEventCard(events[index], context),
                              );
                            },
                          ),
              ),
              if (events.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _activeEventIndexNotifier,
                    builder: (context, activeIndex, _) {
                      final int current = events.isEmpty
                          ? 0
                          : activeIndex.clamp(0, events.length - 1);
                      return _buildHubPageIndicator(
                        currentIndex: current,
                        totalCount: events.length,
                      );
                    },
                  ),
                ),
              if (events.length <= 1) const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowHubButton() {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _isEventsHubHidden = false;
          });
        },
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
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

  Widget _buildHubPageIndicator({
    required int currentIndex,
    required int totalCount,
  }) {
    final int visibleCount = totalCount > 5 ? 5 : totalCount;
    final int startIndex =
        totalCount > 5 ? (currentIndex - 2).clamp(0, totalCount - visibleCount) : 0;
    final int activeDot = (currentIndex - startIndex).clamp(0, visibleCount - 1);

    const double dotSize = 6;
    const double dotGap = 8;
    const double activeWidth = 16;
    final double rowWidth = (visibleCount * dotSize) + ((visibleCount - 1) * dotGap);

    return SizedBox(
      width: rowWidth,
      height: dotSize,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(
              visibleCount,
              (index) => Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: AppColors.dark.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: (activeDot * (dotSize + dotGap)) - ((activeWidth - dotSize) / 2),
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

  Widget _buildEventCard(EventModel event, BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);
    final categoryName = _getCategoryName(event.category);
    final formattedTime = DateFormat(
      'd MMM, HH:mm',
      'ru',
    ).format(event.dateTime);

    return GestureDetector(
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
          if (!mounted || !context.mounted) return;
          context.read<EventBloc>().add(const EventsLoadRequested());
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
              color: AppColors.dark.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Event image
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
                  placeholder: (context, url) => Container(
                    width: 104,
                    height: 112,
                    color: AppColors.accent.withValues(alpha: 0.75),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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

            // Event info
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
                        Container(
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
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
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
                    const SizedBox(height: 6),
                    EventCountdownTimer(
                      expirationTime: event.actualEndDateTime,
                      isMinimal: true,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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
}
