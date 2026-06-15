import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../core/utils/map_viewport_utils.dart';
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
  static const int _viewportEventLimit = 25;
  static const int _maxMapEvents = 40;
  static const int _maxMapMarkers = 12;
  static const int _hubEventLimit = 20;

  late TextEditingController _searchController;
  YandexMapController? _mapController;
  Point? _currentUserLocation;
  Point? _cameraCenter;
  double _cameraZoom = 13;
  final ValueNotifier<int> _activeEventIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<EventModel>> _mapMarkerEventsNotifier =
      ValueNotifier<List<EventModel>>(const []);
  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
  bool _isEventsHubHidden = false;
  bool _isMapGesturing = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  Point? _lastLoadCenter;
  int? _lastLoadRadiusMeters;
  Timer? _hubDebounce;
  Timer? _viewportApiDebounce;
  bool _isViewportRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<EventBloc>().state;
      if (state is EventsLoaded) {
        _applyLoadedEvents(state.events);
      } else if (state is EventError) {
        setState(() {
          _errorMessage = state.message;
          _isInitialLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hubDebounce?.cancel();
    _viewportApiDebounce?.cancel();
    _searchController.dispose();
    _activeEventIndexNotifier.dispose();
    _mapMarkerEventsNotifier.dispose();
    super.dispose();
  }

  bool _sameEventIds(List<EventModel> a, List<EventModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _applyLoadedEvents(List<EventModel> events) {
    final capped = events.length > _maxMapEvents
        ? events.take(_maxMapEvents).toList()
        : events;
    if (_sameEventIds(_allEvents, capped)) {
      if (_isInitialLoading) {
        setState(() => _isInitialLoading = false);
      }
      return;
    }
    _allEvents = capped;
    _recomputeFilteredEvents();
    setState(() {
      _isInitialLoading = false;
      _errorMessage = null;
    });
  }

  Point? get _mapFocusCenter => _cameraCenter ?? _currentUserLocation;

  int _estimatedViewportRadiusMeters() {
    final center = _mapFocusCenter;
    if (center == null) {
      return 2500;
    }
    return mapViewportRadiusFromZoom(_cameraZoom, center.latitude);
  }

  List<EventModel> _eventsNearMapFocus(List<EventModel> events) {
    final center = _mapFocusCenter;
    if (center == null) {
      return events;
    }
    return eventsWithinRadius(events, center, _estimatedViewportRadiusMeters());
  }

  void _updateMapMarkerEvents() {
    final center = _mapFocusCenter;
    if (center == null) {
      return;
    }

    final next = eventsNearestToPoint(
      _eventsNearMapFocus(_allEvents),
      center,
      limit: _maxMapMarkers,
    );
    if (_sameEventIds(_mapMarkerEventsNotifier.value, next)) {
      return;
    }
    _mapMarkerEventsNotifier.value = next;
  }

  void _recomputeFilteredEvents({bool updateMarkers = true}) {
    final normalizedQuery = _searchController.text.trim().toLowerCase();
    final nearbyEvents = _eventsNearMapFocus(_allEvents);

    var out = nearbyEvents.where((event) {
      if (normalizedQuery.isEmpty) return true;
      return event.title.toLowerCase().contains(normalizedQuery) ||
          event.description.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery);
    }).toList();

    final sortCenter = _currentUserLocation ?? _mapFocusCenter;
    if (sortCenter != null) {
      out.sort(
        (a, b) => distanceToPointMeters(
          sortCenter,
          Point(latitude: a.latitude, longitude: a.longitude),
        ).compareTo(
          distanceToPointMeters(
            sortCenter,
            Point(latitude: b.latitude, longitude: b.longitude),
          ),
        ),
      );
    } else {
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    if (out.length > _hubEventLimit) {
      out = out.take(_hubEventLimit).toList();
    }

    _filteredEvents = out;
    if (updateMarkers) {
      _updateMapMarkerEvents();
    }
  }

  Future<void> _loadEventsForViewport({required bool mergeWithExisting}) async {
    final controller = _mapController;
    if (controller == null || _isViewportRequestInFlight) {
      return;
    }

    _isViewportRequestInFlight = true;
    try {
      final region = await controller.getVisibleRegion();
      if (!mounted) return;

      final center = mapViewportCenter(region);
      final radiusMeters = mapViewportRadiusMeters(region);

      if (!shouldReloadMapEvents(
        lastCenter: _lastLoadCenter,
        lastRadiusMeters: _lastLoadRadiusMeters,
        nextCenter: center,
        nextRadiusMeters: radiusMeters,
      )) {
        return;
      }

      _lastLoadCenter = center;
      _lastLoadRadiusMeters = radiusMeters;
      _cameraCenter = center;
      _recomputeFilteredEvents();
      if (mounted) {
        setState(() {});
      }

      context.read<EventBloc>().add(
        EventsLoadRequested(
          latitude: center.latitude,
          longitude: center.longitude,
          maxDistance: radiusMeters,
          limit: _viewportEventLimit,
          mergeWithExisting: mergeWithExisting,
          silent: mergeWithExisting,
        ),
      );
    } finally {
      _isViewportRequestInFlight = false;
    }
  }

  void _scheduleViewportApiLoad({required bool mergeWithExisting}) {
    _viewportApiDebounce?.cancel();
    _viewportApiDebounce = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      unawaited(_loadEventsForViewport(mergeWithExisting: mergeWithExisting));
    });
  }

  void _scheduleHubUpdate() {
    _hubDebounce?.cancel();
    _hubDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _isMapGesturing) return;
      _recomputeFilteredEvents();
      setState(() {});
    });
  }

  void _onCameraPositionChanged(
    CameraPosition cameraPosition,
    CameraUpdateReason reason,
    bool finished,
  ) {
    _cameraCenter = cameraPosition.target;
    _cameraZoom = cameraPosition.zoom;

    if (reason == CameraUpdateReason.gestures && !finished) {
      if (!_isMapGesturing) {
        setState(() => _isMapGesturing = true);
      }
      return;
    }

    if (reason == CameraUpdateReason.gestures && finished) {
      if (_isMapGesturing) {
        setState(() => _isMapGesturing = false);
      }
      _scheduleHubUpdate();
      _scheduleViewportApiLoad(mergeWithExisting: false);
      return;
    }

    if (finished) {
      _scheduleHubUpdate();
      _scheduleViewportApiLoad(mergeWithExisting: false);
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

  void _openSearchScreen() {
    FocusScope.of(context).unfocus();
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
  }

  @override
  Widget build(BuildContext context) {
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

    return BlocListener<EventBloc, EventState>(
      listenWhen: (previous, current) =>
          current is EventsLoaded ||
          current is EventError ||
          (current is EventsLoading && _lastLoadCenter == null),
      listener: (context, state) {
        if (state is EventsLoaded) {
          _applyLoadedEvents(state.events);
        } else if (state is EventError && _lastLoadCenter == null) {
          setState(() {
            _errorMessage = state.message;
            _isInitialLoading = false;
          });
        }
      },
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: _mapMarkerEventsNotifier,
            builder: (context, _) {
              return RepaintBoundary(
                child: YandexMapWidget(
                  events: _mapMarkerEventsNotifier.value,
                  isInteractive: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _scheduleViewportApiLoad(mergeWithExisting: false);
                  },
                  onUserLocationUpdated: (location) {
                    _currentUserLocation = location;
                  },
                  onCameraPositionChanged: _onCameraPositionChanged,
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
                      _scheduleViewportApiLoad(mergeWithExisting: false);
                    });
                  },
                ),
              );
            },
          ),

          MapExploreSearchBar(
            controller: _searchController,
            horizontalInset: navHorizontalInset,
            readOnly: true,
            onOpenSearch: _openSearchScreen,
            onQueryChanged: (_) {},
            onClearQuery: () {
              _searchController.clear();
              setState(_recomputeFilteredEvents);
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
              child: IgnorePointer(
                ignoring: _isMapGesturing,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isMapGesturing ? 0 : 1,
                  child: RepaintBoundary(
                    child: MapNearbyEventsHub(
                      events: _filteredEvents,
                      searchQuery: _searchController.text,
                      hubHeight: eventsHubHeight,
                      activeIndexListenable: _activeEventIndexNotifier,
                      onHideHub: () {
                        setState(() {
                          _isEventsHubHidden = true;
                        });
                      },
                    ),
                  ),
                ),
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

          if (_isInitialLoading)
            const ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_errorMessage != null && _allEvents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
