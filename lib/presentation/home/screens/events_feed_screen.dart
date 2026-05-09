import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../../data/models/event_model.dart';
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

class _EventsFeedScreenState extends State<EventsFeedScreen> {
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
  ];
  Map<String, dynamic> _currentFilters = {
    'category': 'all',
    'date': 'week',
    'sort': 'nearest',
    'price': 'all',
    'format': 'all',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    context.read<EventBloc>().add(const EventsLoadRequested());
  }

  @override
  void dispose() {
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
      final value = (_currentFilters['date'] ?? 'week') as String;
      final local = event.dateTime.toLocal();
      if (value == 'all') return true;
      if (value == 'today') {
        return local.year == now.year && local.month == now.month && local.day == now.day;
      }
      if (value == 'week') {
        final end = now.add(const Duration(days: 7));
        return local.isAfter(now.subtract(const Duration(minutes: 1))) && local.isBefore(end);
      }
      if (value == 'month') {
        final end = DateTime(now.year, now.month + 1, now.day);
        return local.isAfter(now.subtract(const Duration(minutes: 1))) && local.isBefore(end);
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

    final sort = (_currentFilters['sort'] ?? 'nearest') as String;
    if (sort == 'rating') {
      out.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    } else if (sort == 'popular') {
      out.sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
    } else {
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    _filteredEvents = out;
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventBloc, EventState>(
      builder: (context, state) {
        if (state is EventsLoading) {
          return const FeedLoadingSkeleton();
        }

        if (state is EventError) {
          return FeedErrorState(
            message: state.message,
            onRetry: () {
              context.read<EventBloc>().add(const EventsLoadRequested());
            },
          );
        }

        if (state is EventsLoaded) {
          if (!identical(_allEvents, state.events)) {
            _allEvents = state.events;
            _filterEvents(_allEvents, _searchController.text);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<EventBloc>().add(const EventsLoadRequested());
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
              child: ListView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                ),
                children: <Widget>[
                  FeedHeaderCard(
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
                      setState(() {
                        _filterEvents(_allEvents, query);
                      });
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
                  const SizedBox(height: 14),

                  // Carousel section
                  if (state.events.isNotEmpty) ...[
                    const FeedSectionTitle(
                      title: 'Популярные события',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    const SizedBox(height: 10),
                    EventCarousel(
                      events: state.events,
                      onEventSelected: (event) {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    BlocProvider(
                                      create: (context) => EventBloc(),
                                      child: RealEventDetailScreen(
                                        eventId: event.id,
                                      ),
                                    ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const begin = Offset(0.0, 1.0);
                                  const end = Offset.zero;
                                  final curve = Curves.easeOutCubic;
                                  final curvedAnimation = curve.transform(
                                    animation.value,
                                  );
                                  final tween = Tween(begin: begin, end: end);
                                  final offsetAnimation = tween.animate(
                                    AlwaysStoppedAnimation(curvedAnimation),
                                  );

                                  return SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  );
                                },
                            transitionDuration: const Duration(
                              milliseconds: 280,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Regular events list
                  const FeedSectionTitle(
                    title: 'Все события',
                    icon: Icons.view_list_rounded,
                  ),
                  const SizedBox(height: 10),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _filteredEvents.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey<String>('feed-empty'),
                            child: FeedEmptyState(
                              hasSearchQuery: _searchController.text.isNotEmpty,
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              'feed-list-${_filteredEvents.length}-$_selectedCity',
                            ),
                            child: Column(
                              children: _filteredEvents
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final event = entry.value;

                                    return _buildAnimatedFeedListItem(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: FeedEventCard(
                                          event: event,
                                          categoryName: _getCategoryName(
                                            event.category,
                                          ),
                                          categoryColor: _getCategoryColor(
                                            event.category,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
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

  Widget _buildAnimatedFeedListItem({
    required int index,
    required Widget child,
  }) {
    final int clampedIndex = index.clamp(0, 7);
    final int durationMs = 220 + (clampedIndex * 45);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
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
