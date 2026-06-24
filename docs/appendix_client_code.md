lib/presentation/home/screens/map_explore_screen.dart — Экран карты и загрузка событий по viewport

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../core/utils/event_list_filters.dart';
import '../../../core/utils/map_viewport_utils.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../widgets/yandex_map_widget.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/event_service.dart';
import '../screens/search_screen.dart';
import 'map_explore/map_explore_control_buttons.dart';
import 'map_explore/map_explore_filter_button.dart';
import 'map_explore/map_explore_search_bar.dart';
import 'map_explore/map_nearby_events_hub.dart';

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  static const int _viewportEventLimit = 35;
  static const int _maxMapEvents = 60;
  static const int _maxMapMarkers = 15;
  static const int _hubEventLimit = 20;
  static const int _hubFetchLimit = 30;
  static const int _userHubRadiusMeters = 12000;
  static const Duration _viewportDebounce = Duration(milliseconds: 450);
  static const MapAnimation _zoomAnimation = MapAnimation(
    type: MapAnimationType.smooth,
    duration: 0.35,
  );

  late TextEditingController _searchController;
  final EventService _eventService = EventService();
  YandexMapController? _mapController;
  Point? _currentUserLocation;
  Point? _cameraCenter;
  double _cameraZoom = 13;
  final ValueNotifier<int> _activeEventIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<EventModel>> _mapMarkerEventsNotifier =
      ValueNotifier<List<EventModel>>(const []);
  final ValueNotifier<bool> _mapGesturingNotifier = ValueNotifier<bool>(false);
  List<EventModel> _allEvents = [];
  List<EventModel> _hubSourceEvents = [];
  List<EventModel> _filteredEvents = [];
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
  Timer? _gestureEndDebounce;
  bool _isViewportRequestInFlight = false;
  bool _isHubRequestInFlight = false;
  bool _initialViewportLoaded = false;
  Offset? _panStart;
  static const double _panSlop = 12;

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
    _viewportApiDebounce?.cancel();
    _gestureEndDebounce?.cancel();
    _searchController.dispose();
    _activeEventIndexNotifier.dispose();
    _mapMarkerEventsNotifier.dispose();
    _mapGesturingNotifier.dispose();
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
    final merged = <String, EventModel>{
      for (final item in _allEvents) item.id: item,
      for (final item in events) item.id: item,
    };
    var next = merged.values.toList();
    final focus = _mapFocusCenter;
    if (focus != null && next.length > _maxMapEvents) {
      next = eventsNearestToPoint(next, focus, limit: _maxMapEvents);
    } else if (next.length > _maxMapEvents) {
      next = next.take(_maxMapEvents).toList();
    }

    if (_sameEventIds(_allEvents, next)) {
      if (_isInitialLoading) {
        setState(() => _isInitialLoading = false);
      }
      return;
    }
    _allEvents = next;
    _updateMapMarkerEvents();
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

  List<EventModel> _applyMapFilters(List<EventModel> events) {
    return EventListFilters.fromMap(_mapFilters).apply(
      events,
      query: _searchController.text,
      sortLatitude: _currentUserLocation?.latitude,
      sortLongitude: _currentUserLocation?.longitude,
    );
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
      _eventsNearMapFocus(_applyMapFilters(_allEvents)),
      center,
      limit: _maxMapMarkers,
    );
    if (_sameEventIds(_mapMarkerEventsNotifier.value, next)) {
      return;
    }
    _mapMarkerEventsNotifier.value = next;
  }

  void _applyHubFiltersFromSource() {
    var out = _applyMapFilters(_hubSourceEvents);
    final userCenter = _currentUserLocation;
    if (userCenter != null) {
      out = eventsNearestToPoint(out, userCenter, limit: _hubEventLimit);
    } else if (out.length > _hubEventLimit) {
      out = out.take(_hubEventLimit).toList();
    }

    if (_sameEventIds(_filteredEvents, out)) {
      return;
    }
    _filteredEvents = out;
    _activeEventIndexNotifier.value = 0;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadHubEventsFromUserLocation() async {
    final userCenter = _currentUserLocation;
    if (userCenter == null || _isHubRequestInFlight) {
      return;
    }

    _isHubRequestInFlight = true;
    try {
      final events = await _eventService.getEvents(
        latitude: userCenter.latitude,
        longitude: userCenter.longitude,
        maxDistance: _userHubRadiusMeters,
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

  void _requestMapEventsNearUser() {
    final userCenter = _currentUserLocation;
    if (userCenter == null) return;

    context.read<EventBloc>().add(
      EventsLoadRequested(
        latitude: userCenter.latitude,
        longitude: userCenter.longitude,
        maxDistance: _userHubRadiusMeters,
        limit: _viewportEventLimit,
        mergeWithExisting: true,
        silent: true,
      ),
    );
  }

  void _onMapFiltersChanged(Map<String, dynamic> next) {
    setState(() {
      _mapFilters = next;
      _applyHubFiltersFromSource();
      _updateMapMarkerEvents();
    });
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

  void _beginMapGesture() {
    if (_mapGesturingNotifier.value) return;
    _mapGesturingNotifier.value = true;
    _gestureEndDebounce?.cancel();
  }

  void _endMapGesture() {
    _gestureEndDebounce?.cancel();
    _gestureEndDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!_mapGesturingNotifier.value) return;
      _mapGesturingNotifier.value = false;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _panStart = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _panStart;
    if (start == null) return;
    if ((event.position - start).distance >= _panSlop) {
      _beginMapGesture();
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _panStart = null;
  }

  void _onCameraPositionChanged(
    CameraPosition cameraPosition,
    CameraUpdateReason reason,
    bool finished,
  ) {
    _cameraCenter = cameraPosition.target;
    _cameraZoom = cameraPosition.zoom;

    if (reason == CameraUpdateReason.gestures && !finished) {
      _beginMapGesture();
      return;
    }

    if (finished && reason == CameraUpdateReason.gestures) {
      _endMapGesture();
      _updateMapMarkerEvents();
      _scheduleViewportApiLoad(mergeWithExisting: true);
    } else if (finished) {
      _updateMapMarkerEvents();
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
    final double filterBarTop = MediaQuery.paddingOf(context).top + 64;
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
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerUp,
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _mapMarkerEventsNotifier,
                  builder: (context, _) {
                    return YandexMapWidget(
                      events: _mapMarkerEventsNotifier.value,
                      isInteractive: true,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _scheduleViewportApiLoad(
                          mergeWithExisting: true,
                          immediate: true,
                        );
                        if (_currentUserLocation != null) {
                          unawaited(_loadHubEventsFromUserLocation());
                          _requestMapEventsNearUser();
                        }
                      },
                      onUserLocationUpdated: (location) {
                        final hadLocation = _currentUserLocation != null;
                        _currentUserLocation = location;
                        if (!hadLocation) {
                          unawaited(_loadHubEventsFromUserLocation());
                          _requestMapEventsNearUser();
                          _scheduleViewportApiLoad(
                            mergeWithExisting: true,
                            immediate: true,
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
                    );
                  },
                ),
              ),
            ),
          ),

          MapExploreSearchBar(
            controller: _searchController,
            horizontalInset: navHorizontalInset,
            readOnly: true,
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

          MapExploreFilterButton(
            top: filterBarTop,
            horizontalInset: navHorizontalInset,
            filters: _mapFilters,
            onFiltersChanged: _onMapFiltersChanged,
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

          if (!_isEventsHubHidden)
            ValueListenableBuilder<bool>(
              valueListenable: _mapGesturingNotifier,
              builder: (context, mapGesturing, _) {
                return Positioned(
                  left: eventsHubHorizontalInset,
                  right: eventsHubHorizontalInset,
                  bottom: eventsHubBottom,
                  child: IgnorePointer(
                    ignoring: mapGesturing,
                    child: Offstage(
                      offstage: mapGesturing,
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
                );
              },
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

lib/presentation/auth/bloc/auth_bloc.dart — BLoC авторизации

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/services/logger_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  /// Prevents the authStateChanges listener from re-triggering AuthCheckRequested
  /// while a login/register/logout handler is already running.
  bool _handlingAuthAction = false;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) {
    // Регистрируем обработчики событий
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);

    _authStateSubscription = _authService.authStateChanges.listen((_) {
      // Skip if a login/register/logout handler triggered this change
      if (!_handlingAuthAction) {
        add(const AuthCheckRequested());
      }
    });
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.info('🔵 [AuthBloc] Проверка начального состояния...');
    final User? user = _authService.currentUser;
    if (user != null) {
      LoggerService.info('🔵 [AuthBloc] Пользователь найден в Firebase: ${user.email}');
      
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          LoggerService.error('🔴 [AuthBloc] Пользователь удален или заблокирован в Firebase. Выполняю автоматический выход.');
          await _authService.signOut();
          emit(const AuthUnauthenticated());
          return;
        }
      } catch (_) {
        // Игнорируем сетевые ошибки, если нет интернета, чтобы пользователь все равно мог зайти в приложение
        LoggerService.warning('🟡 [AuthBloc] Не удалось выполнить usel.reload(), возможно нет сети.');
      }

      final cachedOnboarding = await _authService.getCachedOnboardingStatus();
      if (cachedOnboarding != null) {
        LoggerService.info('🔵 [AuthBloc] Используем кэш онбординга: $cachedOnboarding');
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: cachedOnboarding));
      }

      try {
        // Загружаем профиль из бэкенда для проверки onboarding
        LoggerService.info('🔵 [AuthBloc] Загрузка профиля из backend...');
        final userProfile = await _authService
            .getCurrentUserProfile()
            .timeout(const Duration(seconds: 6));
        LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
        await _authService.cacheOnboardingStatus(isOnboardingCompleted);
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: isOnboardingCompleted));
      } catch (e) {
        if (cachedOnboarding == null) {
          final isNewUser = (user.metadata.creationTime != null && 
                             DateTime.now().difference(user.metadata.creationTime!) < const Duration(hours: 1));
          final fallbackOnboarding = isNewUser ? false : true;
          
          LoggerService.warning('🟡 [AuthBloc] Профиль не загрузился и кэша нет, fallbackOnboarding=$fallbackOnboarding', e);
          emit(AuthAuthenticated(user: user, isOnboardingCompleted: fallbackOnboarding));
        } else {
          LoggerService.warning('🟡 [AuthBloc] Не удалось загрузить профиль на старте, продолжаем с кэшем', e);
        }
      }
    } else {
      LoggerService.info('🔵 [AuthBloc] Пользователь не найден, показываем Onboarding');
      emit(const AuthUnauthenticated());
    }
  }

  /// Вход через Email и пароль
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка входа: пользователь не найден');
      }

      // Загружаем профиль для проверки onboarding
      try {
        LoggerService.info('🔵 [AuthBloc] Загрузка профиля пользователя...');
        final userProfile = await _authService.getCurrentUserProfile();
        LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
        await _authService.cacheOnboardingStatus(isOnboardingCompleted);
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: isOnboardingCompleted,
        ));
      } catch (e) {
        final cachedOnboarding = await _authService.getCachedOnboardingStatus();
        LoggerService.error('🔴 [AuthBloc] Ошибка загрузки профиля', e);
        
        final isNewUser = (user.metadata.creationTime != null && 
                           DateTime.now().difference(user.metadata.creationTime!) < const Duration(hours: 1));
        
        final fallbackOnboarding = cachedOnboarding ?? (isNewUser ? false : true);
        LoggerService.warning('🟡 [AuthBloc] Используем fallback onboarding=$fallbackOnboarding');
        
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: fallbackOnboarding,
        ));
      }
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Login error: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Регистрация через Email и пароль
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Регистрация началась');
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка регистрации: пользователь не создан');
      }

      // После регистрации пользователь должен пройти онбординг (кэшируем это)
      await _authService.cacheOnboardingStatus(false);

      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: false,
      ));
      LoggerService.debug('🔵 [AuthBloc] AuthAuthenticated эмитен');
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Register error: $e');
      // ПРИМЕЧАНИЕ: Если бэкенд упал, Firebase Auth всё равно мог создать пользователя.
      // Поэтому если мы получили ошибку Backend'а после успешного создания в Firebase, 
      // лучше залогинить его и перебросить на верификацию, иначе он зависнет с ошибкой.
      final user = _authService.currentUser;
      if (user != null) {
         // Сохраняем, что он не прошел онбординг
         await _authService.cacheOnboardingStatus(false);
         emit(AuthAuthenticated(
           user: user,
           isOnboardingCompleted: false,
         ));
      } else {
         emit(AuthFailure(message: e.toString()));
      }
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Вход через Google
  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Google Sign-In requested');
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      LoggerService.debug('🔵 [AuthBloc] Вызываем authService.signInWithGoogleAndGetStatus()');
      final result = await _authService.signInWithGoogleAndGetStatus();
      
      final UserCredential response = result['userCredential'] as UserCredential;
      final bool isOnboardingCompleted = result['isOnboardingCompleted'] as bool;
      
      final user = response.user;
      if (user == null) throw Exception('Ошибка Google Sign-In: пользователь не найден');

      LoggerService.debug('🔵 [AuthBloc] Google Sign-In успешен, isOnboardingCompleted: $isOnboardingCompleted');
      
      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: isOnboardingCompleted,
      ));
      await _authService.cacheOnboardingStatus(isOnboardingCompleted);
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Google Sign-In ошибка: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Выход из системы
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Сброс пароля
  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.resetPassword(event.email);
      emit(const AuthPasswordResetSuccess());
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
      // emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}

lib/core/utils/match_recommendation_utils.dart — Ранжирование кандидатов для ленты

import 'dart:math' as math;

import '../../data/models/user_model.dart';
import '../../presentation/models/match_preview.dart';

/// Rule-based ranking for match feeds (no ML).
class MatchRecommendationUtils {
  static const int incomingLikeBoost = 1000;
  static const int sharedGoingEventWeight = 80;
  static const int commonInterestWeight = 120;
  static const double distancePenaltyPerKm = 3;
  static const int profilePhotoBoost = 15;
  static const int profileBioBoost = 5;
  static const int missingPhotoPenalty = 25;
  static const int missingInterestsPenalty = 20;
  static const int missingBioPenalty = 10;
  static const int emptyProfilePenalty = 60;

  static int scoreUser({
    required UserModel candidate,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    var score = 0;

    if (incomingLikeUserIds.contains(candidate.id)) {
      score += incomingLikeBoost;
    }

    score += (sharedGoingEventCounts[candidate.id] ?? 0) * sharedGoingEventWeight;

    score += _commonInterests(
          currentUser.interests,
          candidate.interests,
        ) *
        commonInterestWeight;

    final candidateLat = candidate.lastLatitude;
    final candidateLon = candidate.lastLongitude;
    final originLat = currentUser.lastLatitude;
    final originLon = currentUser.lastLongitude;
    if (candidateLat != null &&
        candidateLon != null &&
        originLat != null &&
        originLon != null) {
      final distanceKm = _haversineKm(
        originLat,
        originLon,
        candidateLat,
        candidateLon,
      );
      score -= (distanceKm * distancePenaltyPerKm).round();
    }

    if (candidate.photoUrl != null && candidate.photoUrl!.trim().isNotEmpty) {
      score += profilePhotoBoost;
    }
    if (candidate.bio != null && candidate.bio!.trim().isNotEmpty) {
      score += profileBioBoost;
    }

    score -= _profileCompletenessPenalty(candidate);

    return score;
  }

  static int _profileCompletenessPenalty(UserModel candidate) {
    final hasPhoto =
        candidate.photoUrl != null && candidate.photoUrl!.trim().isNotEmpty;
    final hasGallery = candidate.photos.isNotEmpty;
    final hasBio = candidate.bio != null && candidate.bio!.trim().isNotEmpty;
    final hasInterests = candidate.interests.isNotEmpty;

    if (!hasPhoto && !hasGallery && !hasBio && !hasInterests) {
      return emptyProfilePenalty;
    }

    var penalty = 0;
    if (!hasPhoto && !hasGallery) {
      penalty += missingPhotoPenalty;
    }
    if (!hasInterests) {
      penalty += missingInterestsPenalty;
    }
    if (!hasBio) {
      penalty += missingBioPenalty;
    }
    return penalty;
  }

  static Map<String, int> buildSharedGoingEventCounts({
    required Set<String> currentUserGoingEventIds,
    required Map<String, Set<String>> candidateGoingEventIdsByUser,
  }) {
    final counts = <String, int>{};
    for (final entry in candidateGoingEventIdsByUser.entries) {
      final shared = entry.value.intersection(currentUserGoingEventIds).length;
      if (shared > 0) {
        counts[entry.key] = shared;
      }
    }
    return counts;
  }

  static Set<String> goingEventIdsFromParticipated(
    List<dynamic> events,
  ) {
    final ids = <String>{};
    for (final event in events) {
      final status = _participationStatus(event);
      final id = _eventId(event);
      if (id != null && status == 'GOING') {
        ids.add(id);
      }
    }
    return ids;
  }

  static String? _participationStatus(dynamic event) {
    if (event is Map<String, dynamic>) {
      return event['userParticipationStatus'] as String?;
    }
    try {
      return event.userParticipationStatus as String?;
    } catch (_) {
      return null;
    }
  }

  static String? _eventId(dynamic event) {
    if (event is Map<String, dynamic>) {
      return event['id'] as String?;
    }
    try {
      return event.id as String?;
    } catch (_) {
      return null;
    }
  }

  static List<UserModel> sortUsers({
    required List<UserModel> users,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    final sorted = List<UserModel>.from(users);
    sorted.sort((UserModel a, UserModel b) {
      final scoreA = scoreUser(
        candidate: a,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final scoreB = scoreUser(
        candidate: b,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) {
        return byScore;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static List<MatchPreview> sortPreviews({
    required List<MatchPreview> previews,
    required UserModel currentUser,
    Set<String> incomingLikeUserIds = const <String>{},
    Map<String, int> sharedGoingEventCounts = const <String, int>{},
  }) {
    final sorted = List<MatchPreview>.from(previews);
    sorted.sort((MatchPreview a, MatchPreview b) {
      final scoreA = scoreUser(
        candidate: a.userModel,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final scoreB = scoreUser(
        candidate: b.userModel,
        currentUser: currentUser,
        incomingLikeUserIds: incomingLikeUserIds,
        sharedGoingEventCounts: sharedGoingEventCounts,
      );
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) {
        return byScore;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static int _commonInterests(
    List<String> left,
    List<String> right,
  ) {
    final a = left
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final b = right
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    return a.intersection(b).length;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

lib/core/http/api_client.dart — HTTP-клиент с Bearer-токеном

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../auth/id_token_provider.dart';
import '../services/logger_service.dart';

/// Централизованный HTTP-клиент для API запросов.
///
/// Обеспечивает:
/// - Автоматическое добавление Authorization заголовка (Firebase ID Token)
/// - Retry с exponential backoff при 429 (Too Many Requests)
/// - Единый таймаут для всех запросов
/// - Централизованное логирование запросов и ответов
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  factory ApiClient() => _instance;
  ApiClient._internal();

  String get _baseUrl => AppConfig.baseUrl;

  /// GET запрос к API.
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    LoggerService.debug('[ApiClient] GET $uri');
    return _withRetry(() => http.get(uri, headers: headers).timeout(AppConfig.receiveTimeout));
  }

  /// POST запрос к API.
  Future<http.Response> post(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] POST $uri');
    return _withRetry(
      () => http.post(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// PUT запрос к API.
  Future<http.Response> put(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] PUT $uri');
    return _withRetry(
      () => http.put(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// DELETE запрос к API.
  Future<http.Response> delete(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] DELETE $uri');
    return _withRetry(
      () => http.delete(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// Создать multipart запрос с авторизацией.
  Future<Map<String, String>> authHeaders() async {
    return _buildHeaders(requireAuth: true);
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final url = '$_baseUrl$path';
    final uri = Uri.parse(url);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({required bool requireAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token = await _idTokenProvider.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Retry с exponential backoff при 429 (Too Many Requests).
  Future<http.Response> _withRetry(
    Future<http.Response> Function() send, {
    int maxAttempts = 3,
  }) async {
    http.Response? lastResponse;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await send();
        lastResponse = response;

        LoggerService.debug(
          '[ApiClient] Response: ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode != 429) {
          return response;
        }

        if (attempt == maxAttempts) {
          return response;
        }

        final retryAfterRaw =
            response.headers['retry-after'] ?? response.headers['Retry-After'];
        final retryAfterSeconds = int.tryParse((retryAfterRaw ?? '').trim());
        final baseDelayMs = 400 * (1 << (attempt - 1));
        final jitterMs = math.Random().nextInt(200);
        final delay = retryAfterSeconds != null
            ? Duration(seconds: retryAfterSeconds)
            : Duration(milliseconds: baseDelayMs + jitterMs);

        LoggerService.debug('[ApiClient] 429 — retry after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      } on TimeoutException {
        if (attempt == maxAttempts) {
          throw Exception(
            'Таймаут при запросе к API ($_baseUrl). '
            'Если вы на физическом устройстве, укажите IP через '
            '--dart-define=API_BASE_URL=http://<IP>/api',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } on SocketException catch (e) {
        if (attempt == maxAttempts) {
          throw Exception(
            'Не удалось подключиться к API ($_baseUrl): ${e.message}. '
            'Проверьте что backend запущен и устройство в той же сети.',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    return lastResponse!;
  }
}
