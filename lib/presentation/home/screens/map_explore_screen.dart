import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../widgets/yandex_map_widget.dart';
import '../../../data/models/event_model.dart';
import '../screens/search_screen.dart';
import 'map_explore/map_explore_control_buttons.dart';
import 'map_explore/map_explore_search_bar.dart';
import 'map_explore/map_nearby_events_hub.dart';

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
    final normalizedQuery = query.trim().toLowerCase();

    bool matchesQuery(EventModel event) {
      if (normalizedQuery.isEmpty) return true;
      return event.title.toLowerCase().contains(normalizedQuery) ||
          event.description.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery);
    }

    final out = events.where((e) {
      return matchesQuery(e);
    }).toList();

    // Default sort on map: nearest if user known, else by time
    final user = _currentUserLocation;
    if (user != null) {
      double dist(EventModel e) {
        final dx = (e.latitude - user.latitude).abs();
        final dy = (e.longitude - user.longitude).abs();
        return dx + dy;
      }

      out.sort((a, b) => dist(a).compareTo(dist(b)));
    } else {
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    _filteredEvents = out;
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

        // Применяем текущие фильтры при загрузке/обновлении списка.
        if (_filteredEvents.isEmpty || _searchController.text.isEmpty) {
          _filterEvents(events, _searchController.text);
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

            MapExploreSearchBar(
              controller: _searchController,
              horizontalInset: navHorizontalInset,
              onOpenSearch: () {
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
              onQueryChanged: (query) {
                setState(() {
                  _filterEvents(events, query);
                });
              },
              onClearQuery: () {
                _searchController.clear();
                setState(() {
                  _filterEvents(events, '');
                });
              },
            ),

            MapExploreControlButtons(
              bottom: controlsBottom,
              onCenter: () {
                HapticFeedback.selectionClick();
                _centerOnUserLocation();
              },
              onZoomIn: () {
                HapticFeedback.selectionClick();
                _mapController?.moveCamera(
                  CameraUpdate.zoomIn(),
                  animation: const MapAnimation(
                    type: MapAnimationType.smooth,
                    duration: 0.3,
                  ),
                );
              },
              onZoomOut: () {
                HapticFeedback.selectionClick();
                _mapController?.moveCamera(
                  CameraUpdate.zoomOut(),
                  animation: const MapAnimation(
                    type: MapAnimationType.smooth,
                    duration: 0.3,
                  ),
                );
              },
            ),

            if (!_isEventsHubHidden)
              Positioned(
                left: eventsHubHorizontalInset,
                right: eventsHubHorizontalInset,
                bottom: eventsHubBottom,
                child: MapNearbyEventsHub(
                  events: _filteredEvents,
                  searchQuery: _searchController.text,
                  hubHeight: eventsHubHeight,
                  activeIndexListenable: _activeEventIndexNotifier,
                  onFocusEvent: _focusOnEvent,
                  onHideHub: () {
                    setState(() {
                      _isEventsHubHidden = true;
                    });
                  },
                ),
              ),

            if (_isEventsHubHidden)
              Positioned(
                left: eventsHubHorizontalInset,
                bottom: eventsHubBottom + 8,
                child: MapExploreShowHubButton(
                  onShowHub: () {
                    setState(() {
                      _isEventsHubHidden = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
