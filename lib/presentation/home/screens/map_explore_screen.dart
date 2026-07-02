import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/events/event_refresh_listener.dart';
import '../../../core/utils/event_list_filters.dart';
import '../../../core/utils/map_viewport_utils.dart';
import '../../../core/utils/match_recommendation_utils.dart';
import '../../../data/models/map_user_preview.dart';
import '../../../data/services/user_service.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/yandex_map_widget.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/event_service.dart';
import '../screens/search_screen.dart';
import 'map_explore/map_explore_control_buttons.dart';
import 'map_explore/map_explore_search_bar.dart';
import 'map_explore/map_nearby_events_hub.dart';

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen>
    with AutomaticKeepAliveClientMixin, EventRefreshListener<MapExploreScreen> {
  static const int _viewportEventLimit = 35;
  static const int _maxMapEvents = 60;
  static const int _maxMapMarkers = 15;
  static const int _maxMapUsers = 25;
  static const int _hubEventLimit = 20;
  static const int _hubFetchLimit = 30;
  static const int _hubRadiusMeters = 5000;
  static const Duration _viewportDebounce = Duration(milliseconds: 600);
  static const Duration _mapUsersRefreshInterval = Duration(seconds: 30);
  static const Point _defaultMapCenter = Point(
    latitude: 58.603591,
    longitude: 49.668023,
  );
  static const MapAnimation _zoomAnimation = MapAnimation(
    type: MapAnimationType.smooth,
    duration: 0.35,
  );

  late TextEditingController _searchController;
  final EventService _eventService = EventService();
  final UserService _userService = UserService();
  YandexMapController? _mapController;
  Point? _currentUserLocation;
  Point? _cameraCenter;
  double _cameraZoom = 13;
  final ValueNotifier<int> _activeEventIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<EventModel>> _mapMarkerEventsNotifier =
      ValueNotifier<List<EventModel>>(const []);
  final ValueNotifier<List<MapUserPreview>> _mapMarkerUsersNotifier =
      ValueNotifier<List<MapUserPreview>>(const []);
  final ValueNotifier<List<EventModel>> _hubEventsNotifier =
      ValueNotifier<List<EventModel>>(const []);
  List<EventModel> _allEvents = [];
  List<MapUserPreview> _allMapUsers = [];
  List<EventModel> _hubSourceEvents = [];
  Map<String, dynamic> _mapFilters = const {
    'category': 'all',
    'date': 'week',
    'sort': 'nearest',
    'price': 'all',
    'format': 'all',
  };
  bool _isEventsHubHidden = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  Point? _lastLoadCenter;
  int? _lastLoadRadiusMeters;
  Timer? _viewportApiDebounce;
  Timer? _mapUsersRefreshTimer;
  bool _isViewportRequestInFlight = false;
  bool _isMapUsersRequestInFlight = false;
  bool _isHubRequestInFlight = false;
  bool _initialViewportLoaded = false;
  bool _initialDataLoadScheduled = false;

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
    _mapUsersRefreshTimer = Timer.periodic(_mapUsersRefreshInterval, (_) {
      if (!mounted || !shouldShowMapUserMarkers(_cameraZoom)) return;
      unawaited(_refreshMapUsersForCurrentView());
    });
  }

  Future<void> _refreshMapUsersForCurrentView() async {
    if (_mapController == null) return;
    final radiusKm = math.max(
      _estimatedViewportRadiusMeters() / 1000.0,
      mapUsersFetchMinRadiusKm,
    );
    await _loadMapUsersForViewport(
      latitude: _mapFocusCenter.latitude,
      longitude: _mapFocusCenter.longitude,
      radiusKm: radiusKm,
    );
  }

  @override
  void onEventsShouldRefresh() {
    _refreshAllEventData();
  }

  void _refreshAllEventData() {
    _lastLoadCenter = null;
    _lastLoadRadiusMeters = null;
    unawaited(_loadHubEventsFromUserLocation());
    unawaited(_refreshMapUsersForCurrentView());
    if (_mapController != null) {
      _scheduleViewportApiLoad(mergeWithExisting: true, immediate: true);
    } else {
      context.read<EventBloc>().add(
        const EventsLoadRequested(
          skipCache: true,
          mergeWithExisting: true,
          silent: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _viewportApiDebounce?.cancel();
    _mapUsersRefreshTimer?.cancel();
    _searchController.dispose();
    _activeEventIndexNotifier.dispose();
    _mapMarkerEventsNotifier.dispose();
    _mapMarkerUsersNotifier.dispose();
    _hubEventsNotifier.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool _sameEventIds(List<EventModel> a, List<EventModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _applyLoadedEvents(List<EventModel> events) {
    final merged = <String, EventModel>{
      for (final item in _allEvents) item.id: item,
      for (final item in events) item.id: item,
    };
    var next = merged.values.toList();
    if (next.length > _maxMapEvents) {
      next = eventsNearestToPoint(
        next,
        _mapFocusCenter,
        limit: _maxMapEvents,
      );
    }

    if (_sameEventIds(_allEvents, next)) {
      if (_isInitialLoading) {
        setState(() => _isInitialLoading = false);
      }
      return;
    }
    _allEvents = next;
    _updateMapMarkerEvents();
    _updateMapMarkerUsers();
    if (_isInitialLoading || _errorMessage != null) {
      setState(() {
        _isInitialLoading = false;
        _errorMessage = null;
      });
    }
  }

  Point get _mapFocusCenter =>
      _cameraCenter ?? _currentUserLocation ?? _defaultMapCenter;

  int _estimatedViewportRadiusMeters() {
    return mapViewportRadiusFromZoom(
      _cameraZoom,
      _mapFocusCenter.latitude,
    );
  }

  List<EventModel> _applyMapFilters(List<EventModel> events) {
    return EventListFilters.fromMap(_mapFilters).apply(
      events,
      query: _searchController.text,
      sortLatitude: _currentUserLocation?.latitude,
      sortLongitude: _currentUserLocation?.longitude,
    );
  }

  List<EventModel> _eventsNearMapFocus(List<EventModel> events) {
    return eventsWithinRadius(
      events,
      _mapFocusCenter,
      _estimatedViewportRadiusMeters(),
    );
  }

  void _updateMapMarkerEvents() {
    final center = _mapFocusCenter;
    final next = eventsNearestToPoint(
      _eventsNearMapFocus(_applyMapFilters(_allEvents)),
      center,
      limit: _maxMapMarkers,
    );
    if (_sameEventIds(_mapMarkerEventsNotifier.value, next)) {
      return;
    }
    _mapMarkerEventsNotifier.value = next;
    _updateMapMarkerUsers();
  }

  void _updateMapMarkerUsers() {
    if (!shouldShowMapUserMarkers(_cameraZoom)) {
      if (_mapMarkerUsersNotifier.value.isEmpty) {
        return;
      }
      _mapMarkerUsersNotifier.value = const [];
      return;
    }

    final center = _mapFocusCenter;
    final radiusMeters = math.max(
      _estimatedViewportRadiusMeters(),
      _hubRadiusMeters,
    );
    final withDistance = <({MapUserPreview user, double distance})>[];
    for (final user in _allMapUsers) {
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        user.latitude,
        user.longitude,
      );
      if (distance <= radiusMeters) {
        withDistance.add((user: user, distance: distance));
      }
    }
    withDistance.sort((a, b) => a.distance.compareTo(b.distance));

    final visible = withDistance.map((entry) => entry.user).toList();

    final next = visible.length > _maxMapUsers
        ? visible.take(_maxMapUsers).toList()
        : visible;

    if (_sameMapUserIds(_mapMarkerUsersNotifier.value, next)) {
      return;
    }
    _mapMarkerUsersNotifier.value = next;
  }

  bool _sameMapUserIds(List<MapUserPreview> a, List<MapUserPreview> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _applyHubFiltersFromSource() {
    var out = _applyMapFilters(_hubSourceEvents);
    final userCenter = _currentUserLocation;
    if (userCenter != null) {
      out = eventsNearestToPoint(out, userCenter, limit: _hubEventLimit);
    } else if (out.length > _hubEventLimit) {
      out = out.take(_hubEventLimit).toList();
    }

    if (_sameEventIds(_hubEventsNotifier.value, out)) {
      return;
    }
    _hubEventsNotifier.value = out;
    _activeEventIndexNotifier.value = 0;
  }

  Future<void> _loadHubEventsFromUserLocation() async {
    if (_isHubRequestInFlight) {
      return;
    }

    _isHubRequestInFlight = true;
    try {
      final hubCenter = _currentUserLocation ?? _mapFocusCenter;
      final events = await _eventService.getEvents(
        latitude: hubCenter.latitude,
        longitude: hubCenter.longitude,
        maxDistance: _hubRadiusMeters,
        limit: _hubFetchLimit,
        writeCache: false,
      );
      if (!mounted) return;
      _hubSourceEvents = events;
      _applyHubFiltersFromSource();
    } catch (_) {
      if (!mounted) return;
      if (_hubSourceEvents.isEmpty) {
        _applyHubFiltersFromSource();
      }
    } finally {
      _isHubRequestInFlight = false;
    }
  }

  void _scheduleInitialDataLoad() {
    if (_initialDataLoadScheduled || _mapController == null) return;
    _initialDataLoadScheduled = true;
    _scheduleViewportApiLoad(mergeWithExisting: true, immediate: true);
    unawaited(_loadHubEventsFromUserLocation());
  }

  void _scheduleInitialDataLoadAfterMapReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _scheduleInitialDataLoad();
      });
    });
  }

  void _onMapFiltersChanged(Map<String, dynamic> next) {
    setState(() {
      _mapFilters = next;
      _applyHubFiltersFromSource();
      _updateMapMarkerEvents();
      _updateMapMarkerUsers();
    });
  }

  Future<void> _loadMapUsersForViewport({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    if (_isMapUsersRequestInFlight) return;

    _isMapUsersRequestInFlight = true;
    try {
      final fetchRadiusKm = radiusKm < mapUsersFetchMinRadiusKm
          ? mapUsersFetchMinRadiusKm
          : radiusKm;
      final users = await _userService.getMapUsers(
        latitude: latitude,
        longitude: longitude,
        radiusKm: fetchRadiusKm,
        limit: 40,
      );
      if (!mounted) return;

      final merged = <String, MapUserPreview>{
        for (final item in _allMapUsers) item.id: item,
        for (final item in users) item.id: item,
      };
      _allMapUsers = merged.values.toList();
      _updateMapMarkerUsers();
    } catch (e, stackTrace) {
      LoggerService.error('[MapExplore] getMapUsers failed', e, stackTrace);
    } finally {
      _isMapUsersRequestInFlight = false;
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
      _initialViewportLoaded = true;
      _updateMapMarkerEvents();
      _updateMapMarkerUsers();

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

      unawaited(
        _loadMapUsersForViewport(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusKm: radiusMeters / 1000.0,
        ),
      );
    } finally {
      _isViewportRequestInFlight = false;
    }
  }

  void _scheduleViewportApiLoad({
    required bool mergeWithExisting,
    bool immediate = false,
  }) {
    _viewportApiDebounce?.cancel();
    if (immediate || !_initialViewportLoaded) {
      unawaited(_loadEventsForViewport(mergeWithExisting: mergeWithExisting));
      return;
    }
    _viewportApiDebounce = Timer(_viewportDebounce, () {
      if (!mounted) return;
      unawaited(_loadEventsForViewport(mergeWithExisting: mergeWithExisting));
    });
  }

  void _onCameraPositionChanged(
    CameraPosition cameraPosition,
    CameraUpdateReason reason,
    bool finished,
  ) {
    final previousZoom = _cameraZoom;
    _cameraCenter = cameraPosition.target;
    _cameraZoom = cameraPosition.zoom;

    final usersVisibilityChanged = shouldShowMapUserMarkers(previousZoom) !=
        shouldShowMapUserMarkers(_cameraZoom);
    if (usersVisibilityChanged) {
      _updateMapMarkerUsers();
    }

    if (!finished) {
      return;
    }

    _updateMapMarkerEvents();
    if (!usersVisibilityChanged) {
      _updateMapMarkerUsers();
    }
    _scheduleViewportApiLoad(mergeWithExisting: true);
    if (_allMapUsers.isEmpty && shouldShowMapUserMarkers(_cameraZoom)) {
      unawaited(
        _loadMapUsersForViewport(
          latitude: _mapFocusCenter.latitude,
          longitude: _mapFocusCenter.longitude,
          radiusKm: mapUsersFetchMinRadiusKm,
        ),
      );
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
          duration: 0.35,
        ),
      );
      _scheduleViewportApiLoad(mergeWithExisting: true, immediate: true);
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

  Future<void> _openUserProfile(MapUserPreview preview) async {
    HapticFeedback.selectionClick();
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _userService.getUserById(preview.id),
        _userService.getCurrentUser(),
      ]);
      final user = results[0] as UserModel;
      final currentUser = results[1] as UserModel;
      final commonInterests = MatchRecommendationUtils.commonInterestLabels(
        left: currentUser.interests,
        right: user.interests,
      );

      if (!mounted) return;
      await Navigator.push<void>(
        context,
        CupertinoPageRoute<void>(
          builder: (context) => UserProfileScreen.fromUser(
            user: user,
            commonInterests: commonInterests,
            canViewSensitiveInfo: false,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть профиль')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          Positioned.fill(
            child: RepaintBoundary(
              child: ListenableBuilder(
                  listenable: Listenable.merge(
                    <Listenable>[
                      _mapMarkerEventsNotifier,
                      _mapMarkerUsersNotifier,
                    ],
                  ),
                  builder: (context, _) {
                    return YandexMapWidget(
                      events: _mapMarkerEventsNotifier.value,
                      users: _mapMarkerUsersNotifier.value,
                      isInteractive: true,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _cameraCenter ??= _defaultMapCenter;
                        _scheduleInitialDataLoadAfterMapReady();
                      },
                      onUserLocationUpdated: (location) {
                        final hadLocation = _currentUserLocation != null;
                        _currentUserLocation = location;
                        if (!hadLocation) {
                          unawaited(_loadHubEventsFromUserLocation());
                        }
                        if (!_initialViewportLoaded) {
                          _scheduleViewportApiLoad(
                            mergeWithExisting: true,
                            immediate: true,
                          );
                        } else if (_allMapUsers.isEmpty) {
                          unawaited(
                            _loadMapUsersForViewport(
                              latitude: location.latitude,
                              longitude: location.longitude,
                              radiusKm: mapUsersFetchMinRadiusKm,
                            ),
                          );
                        }
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
                          _scheduleViewportApiLoad(
                            mergeWithExisting: true,
                            immediate: true,
                          );
                        });
                      },
                      onUserMarkerTapped: (user) {
                        unawaited(_openUserProfile(user));
                      },
                    );
                  },
                ),
              ),
            ),

          MapExploreSearchBar(
            controller: _searchController,
            horizontalInset: navHorizontalInset,
            readOnly: true,
            filters: _mapFilters,
            onFiltersChanged: _onMapFiltersChanged,
            onOpenSearch: _openSearchScreen,
            onQueryChanged: (_) {},
            onClearQuery: () {
              _searchController.clear();
              setState(() {
                _applyHubFiltersFromSource();
                _updateMapMarkerEvents();
              });
            },
          ),

          MapExploreControlButtons(
            bottom: controlsBottom,
            onCenter: () {
              _centerOnUserLocation();
            },
            onZoomIn: () {
              _mapController?.moveCamera(
                CameraUpdate.zoomIn(),
                animation: _zoomAnimation,
              );
            },
            onZoomOut: () {
              _mapController?.moveCamera(
                CameraUpdate.zoomOut(),
                animation: _zoomAnimation,
              );
            },
          ),

          Positioned(
            left: eventsHubHorizontalInset,
            right: eventsHubHorizontalInset,
            bottom: eventsHubBottom,
            child: RepaintBoundary(
              child: ValueListenableBuilder<List<EventModel>>(
                valueListenable: _hubEventsNotifier,
                builder: (context, hubEvents, _) {
                  return MapExploreEventsHubSlot(
                    expanded: !_isEventsHubHidden,
                    hubHeight: eventsHubHeight,
                    hub: MapNearbyEventsHub(
                      events: hubEvents,
                      searchQuery: _searchController.text,
                      hubHeight: eventsHubHeight,
                      activeIndexListenable: _activeEventIndexNotifier,
                      onHideHub: () {
                        setState(() {
                          _isEventsHubHidden = true;
                        });
                      },
                      onEventDetailClosed: () {
                        _scheduleViewportApiLoad(
                          mergeWithExisting: true,
                          immediate: true,
                        );
                      },
                    ),
                    collapsedButton: MapExploreShowHubButton(
                      onShowHub: () {
                        setState(() {
                          _isEventsHubHidden = false;
                        });
                      },
                    ),
                  );
                },
              ),
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
