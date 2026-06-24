import 'dart:math';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/events/event_refresh_listener.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/event_recommendation_utils.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/user_service.dart';
import '../../widgets/event_carousel.dart';
import './search_screen.dart';
import 'events_feed/events_feed_widgets.dart';
import 'events_feed/feed_city_picker_sheet.dart';
import 'events_feed/feed_event_card.dart';
import 'events_feed/feed_header_card.dart';

class EventsFeedScreen extends StatefulWidget {
  const EventsFeedScreen({super.key});

  @override
  State<EventsFeedScreen> createState() => _EventsFeedScreenState();
}

class _EventsFeedScreenState extends State<EventsFeedScreen>
    with EventRefreshListener<EventsFeedScreen> {
  late TextEditingController _searchController;
  List<EventModel> _filteredEvents = [];
  List<EventModel> _allEvents = [];
  double? _selectedCityLatitude;
  double? _selectedCityLongitude;
  String _selectedCity = 'Все города';
  final List<String> _cities = [
    'Все города',
    'Москва',
    'Санкт-Петербург',
    'Казань',
    'Екатеринбург',
    'Новосибирск',
    'Сочи',
    'Ростов-на-Дону',
    'Уфа',
    'Краснодар',
    'Пермь',
    'Киров',
  ];
  Map<String, dynamic> _currentFilters = {
    'category': 'all',
    'date': 'all',
    'sort': 'recommended',
    'price': 'all',
    'format': 'all',
  };
  Timer? _searchDebounce;
  final UserService _userService = UserService();
  final EventService _eventService = EventService();
  EventRecommendationProfile _recommendationProfile =
      const EventRecommendationProfile(user: null, preferredCategories: {});

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    context.read<EventBloc>().add(const EventsLoadRequested());
    _loadRecommendationProfile();
  }

  @override
  void onEventsShouldRefresh() {
    context.read<EventBloc>().add(
      const EventsLoadRequested(skipCache: true, silent: true),
    );
    _loadRecommendationProfile();
  }

  Future<void> _loadRecommendationProfile() async {
    try {
      final user = await _userService.getCurrentUser();
      List<EventModel> participated = const <EventModel>[];
      try {
        participated = await _eventService.getUserParticipatedEvents(user.id);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _recommendationProfile = EventRecommendationUtils.buildProfile(
          user: user,
          participatedEvents: participated,
        );
        _filterEvents(_allEvents, _searchController.text);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendationProfile = const EventRecommendationProfile(
          user: null,
          preferredCategories: {},
        );
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCityBottomSheet() async {
    final List<String> cityOptions = _buildCityOptions();

    final CitySelection? pickedCity =
        await showModalBottomSheet<CitySelection>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (BuildContext context) => FeedCityPickerSheet(
            cityOptions: cityOptions,
            selectedCity: _selectedCity,
          ),
        );

    if (!mounted || pickedCity == null) {
      return;
    }

    if (pickedCity.cityName == _selectedCity &&
        pickedCity.latitude == _selectedCityLatitude &&
        pickedCity.longitude == _selectedCityLongitude) {
      return;
    }

    setState(() {
      _selectedCity = pickedCity.cityName;
      _selectedCityLatitude = pickedCity.latitude;
      _selectedCityLongitude = pickedCity.longitude;
      _filterEvents(_allEvents, _searchController.text);
    });
  }

  void _handleFiltersChanged(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
      _filterEvents(_allEvents, _searchController.text);
    });
    LoggerService.debug('Filters changed: $filters');
  }

  void _filterEvents(List<EventModel> events, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final now = DateTime.now();

    bool matchesDate(EventModel event) {
      final value = (_currentFilters['date'] ?? 'all') as String;
      if (value == 'all') return true;

      final start = event.dateTime.toLocal();
      final end = event.actualEndDateTime.toLocal();

      if (value == 'today') {
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        return end.isAfter(todayStart) && start.isBefore(todayEnd);
      }
      if (value == 'week') {
        final windowEnd = now.add(const Duration(days: 7));
        return end.isAfter(now) && start.isBefore(windowEnd);
      }
      if (value == 'month') {
        final windowEnd = DateTime(now.year, now.month + 1, now.day);
        return end.isAfter(now) && start.isBefore(windowEnd);
      }
      return true;
    }

    bool matchesCategory(EventModel event) {
      final value = (_currentFilters['category'] ?? 'all') as String;
      if (value == 'all') return true;
      return event.category.toLowerCase() == value.toLowerCase();
    }

    bool matchesPrice(EventModel event) {
      final value = (_currentFilters['price'] ?? 'all') as String;
      if (value == 'all') return true;
      if (value == 'free') return event.price == 0;
      if (value == 'paid') return event.price > 0;
      return true;
    }

    bool matchesFormat(EventModel event) {
      final value = (_currentFilters['format'] ?? 'all') as String;
      if (value == 'all') return true;
      if (value == 'online') return event.isOnline;
      if (value == 'offline') return !event.isOnline;
      return true;
    }

    List<EventModel> out = events.where((event) {
      final matchesCity = _matchesSelectedCity(event);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          event.title.toLowerCase().contains(normalizedQuery) ||
          event.description.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery) ||
          event.category.toLowerCase().contains(normalizedQuery);

      return matchesCity &&
          matchesQuery &&
          matchesDate(event) &&
          matchesCategory(event) &&
          matchesPrice(event) &&
          matchesFormat(event);
    }).toList();

    final sort = (_currentFilters['sort'] ?? 'recommended') as String;
    if (sort == 'rating') {
      out.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    } else if (sort == 'popular') {
      out.sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
    } else if (sort == 'nearest') {
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } else {
      final origin = _recommendationOrigin();
      out = EventRecommendationUtils.sortEvents(
        events: out,
        profile: _recommendationProfile,
        originLatitude: origin.$1,
        originLongitude: origin.$2,
      );
    }

    out = _pinOwnEventsFirst(out);

    _filteredEvents = out;
  }

  List<EventModel> _pinOwnEventsFirst(List<EventModel> events) {
    final userId = _recommendationProfile.user?.id;
    if (userId == null || userId.isEmpty) return events;

    final own = <EventModel>[];
    final rest = <EventModel>[];
    for (final event in events) {
      if (event.createdById == userId) {
        own.add(event);
      } else {
        rest.add(event);
      }
    }

    if (own.isEmpty) return events;
    return <EventModel>[...own, ...rest];
  }

  List<String> _buildCityOptions() {
    final Set<String> citiesFromEvents = _allEvents
        .map((e) => _extractCityName(e.location))
        .where((city) => city.isNotEmpty)
        .toSet();

    final Set<String> merged = <String>{..._cities, ...citiesFromEvents};

    final List<String> sorted =
        merged.where((city) => city != 'Все города').toList()
          ..sort((a, b) => a.compareTo(b));

    return <String>['Все города', ...sorted];
  }

  String _extractCityName(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return '';

    final firstChunk = trimmed.split(',').first.trim();
    if (firstChunk.isEmpty) return trimmed;
    return firstChunk;
  }

  bool _matchesSelectedCity(EventModel event) {
    if (_selectedCity == 'Все города') return true;

    // Если выбрана точка города через геокодер, фильтруем события по радиусу.
    if (_selectedCityLatitude != null && _selectedCityLongitude != null) {
      const radiusMeters = 120000.0; // ~120 км вокруг выбранного города
      final distance = _distanceMeters(
        lat1: _selectedCityLatitude!,
        lon1: _selectedCityLongitude!,
        lat2: event.latitude,
        lon2: event.longitude,
      );
      if (distance <= radiusMeters) {
        return true;
      }
    }

    final location = _normalizeForCompare(event.location);
    final selected = _normalizeForCompare(_selectedCity);

    if (location.contains(selected)) return true;

    // Небольшой набор синонимов для частых написаний города
    final aliases = <String, List<String>>{
      'санктпетербург': <String>['спб', 'питер'],
      'ростовнадону': <String>['ростов на дону', 'ростов'],
    };

    final aliasList = aliases[selected] ?? const <String>[];
    for (final alias in aliasList) {
      if (location.contains(_normalizeForCompare(alias))) {
        return true;
      }
    }

    return false;
  }

  double _distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (3.141592653589793 / 180);

  String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  List<EventModel> get _popularCarouselEvents {
    final now = DateTime.now();
    final upcoming = _allEvents
        .where((event) => event.actualEndDateTime.toLocal().isAfter(now))
        .toList()
      ..sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
    return _pinOwnEventsFirst(upcoming);
  }

  void _syncEventsFromBloc(List<EventModel> events) {
    _allEvents = events;
    _filterEvents(_allEvents, _searchController.text);
  }

  (double?, double?) _recommendationOrigin() {
    if (_selectedCityLatitude != null && _selectedCityLongitude != null) {
      return (_selectedCityLatitude, _selectedCityLongitude);
    }

    final user = _recommendationProfile.user;
    if (user?.lastLatitude != null && user?.lastLongitude != null) {
      return (user!.lastLatitude, user.lastLongitude);
    }

    return (null, null);
  }

  void _openEventDetail(EventModel event) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BlocProvider(
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

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventBloc, EventState>(
      listenWhen: (previous, current) => current is EventsLoaded,
      listener: (context, state) {
        if (state is! EventsLoaded) return;
        setState(() => _syncEventsFromBloc(state.events));
      },
      buildWhen: (previous, current) =>
          current is EventsLoading ||
          current is EventsLoaded ||
          current is EventError,
      builder: (context, state) {
        if (state is EventsLoading) {
          return const FeedLoadingSkeleton();
        }

        if (state is EventError) {
          return FeedErrorState(
            message: state.message,
            onRetry: () {
              context.read<EventBloc>().add(
                const EventsLoadRequested(skipCache: true),
              );
            },
          );
        }

        if (state is EventsLoaded) {
          if (!identical(_allEvents, state.events)) {
            _syncEventsFromBloc(state.events);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<EventBloc>().add(
                const EventsLoadRequested(skipCache: true),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.surface.withValues(alpha: 0.94),
                    AppColors.accent.withValues(alpha: 0.74),
                    AppColors.surface.withValues(alpha: 0.98),
                  ],
                ),
              ),
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: MediaQuery.of(context).padding.top + 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: FeedHeaderCard(
                        filteredCount: _filteredEvents.length,
                        searchController: _searchController,
                        selectedCity: _selectedCity,
                        onOpenSearch: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      BlocProvider(
                                        create: (context) => EventBloc(),
                                        child: SearchScreen(
                                          initialQuery: _searchController.text,
                                        ),
                                      ),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                final curve = Curves.easeOutCubic;
                                final curvedAnimation =
                                    curve.transform(animation.value);
                                final tween = Tween(begin: begin, end: end);
                                final offsetAnimation = tween.animate(
                                  AlwaysStoppedAnimation(curvedAnimation),
                                );

                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 280),
                            ),
                          );
                        },
                        onQueryChanged: (query) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 250),
                            () {
                              if (!mounted) return;
                              setState(() {
                                _filterEvents(_allEvents, query);
                              });
                            },
                          );
                        },
                        onClearQuery: () {
                          _searchController.clear();
                          setState(() {
                            _filterEvents(_allEvents, '');
                          });
                        },
                        onPickCity: _showCityBottomSheet,
                        filters: _currentFilters,
                        onFiltersChanged: _handleFiltersChanged,
                      ),
                    ),
                  ),
                  if (_popularCarouselEvents.isNotEmpty) ...[
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: FeedSectionTitle(
                          title: 'Популярные события',
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: EventCarousel(
                          events: _popularCarouselEvents,
                          onEventSelected: _openEventDetail,
                        ),
                      ),
                    ),
                  ],
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: FeedSectionTitle(
                        title: 'Все события',
                        icon: Icons.view_list_rounded,
                      ),
                    ),
                  ),
                  if (_filteredEvents.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: FeedEmptyState(
                          hasSearchQuery: _searchController.text.isNotEmpty,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final event = _filteredEvents[index];
                            return RepaintBoundary(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: FeedEventCard(
                                  key: ValueKey<String>(event.id),
                                  event: event,
                                  categoryName: _getCategoryName(event.category),
                                  categoryColor: _getCategoryColor(event.category),
                                ),
                              ),
                            );
                          },
                          childCount: _filteredEvents.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return const Center(child: Text('Загрузка событий...'));
      },
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
        return const Color(0xFF2E7DFF);
      case 'sport':
        return const Color(0xFF0FA958);
      case 'exhibition':
        return const Color(0xFF0D8F8A);
      case 'conference':
        return const Color(0xFF3B66D9);
      case 'party':
        return const Color(0xFFF48A2A);
      case 'theater':
        return const Color(0xFFCC4B4B);
      case 'cinema':
        return const Color(0xFF4D5B7C);
      case 'other':
        return const Color(0xFF75878A);
      default:
        return const Color(0xFF75878A);
    }
  }

}
