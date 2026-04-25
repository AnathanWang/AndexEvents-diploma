import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/geocoding_service.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../../data/models/event_model.dart';
import '../../widgets/event_carousel.dart';
import '../../widgets/event_filters.dart';
import '../../widgets/event_countdown_timer.dart';
import './search_screen.dart';

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

    final _CitySelection? pickedCity =
        await showModalBottomSheet<_CitySelection>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (BuildContext context) => _CityPickerSheet(
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
    });
    LoggerService.debug('Filters changed: $filters');
  }

  void _filterEvents(List<EventModel> events, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    _filteredEvents = events.where((event) {
      final matchesCity = _matchesSelectedCity(event);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          event.title.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery) ||
          event.category.toLowerCase().contains(normalizedQuery);

      return matchesCity && matchesQuery;
    }).toList();
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

  String _creatorInitial(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventBloc, EventState>(
      builder: (context, state) {
        if (state is EventsLoading) {
          return _buildLoadingSkeleton(context);
        }

        if (state is EventError) {
          return _buildFeedErrorState(context, state.message);
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
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
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Афиша города',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dark.withValues(alpha: 0.88),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.event_outlined,
                                    size: 13,
                                    color: AppColors.primary.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_filteredEvents.length}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        BlocProvider(
                                          create: (context) => EventBloc(),
                                          child: SearchScreen(
                                            initialQuery:
                                                _searchController.text,
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
                                      final tween = Tween(
                                        begin: begin,
                                        end: end,
                                      );
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
                          onChanged: (query) {
                            setState(() {
                              _filterEvents(_allEvents, query);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Поиск событий...',
                            hintStyle: TextStyle(
                              color: AppColors.dark.withValues(alpha: 0.52),
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.dark.withValues(alpha: 0.6),
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    color: AppColors.dark.withValues(alpha: 0.6),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterEvents(_allEvents, '');
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                width: 1.2,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.surface.withValues(alpha: 0.84),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showCityBottomSheet,
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minHeight: 44),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          Icons.location_on_outlined,
                                          color: AppColors.primary.withValues(alpha: 0.86),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 110),
                                          child: Text(
                                            _selectedCity,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.dark.withValues(alpha: 0.84),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.expand_more,
                                          color: AppColors.dark.withValues(alpha: 0.58),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: EventFiltersWidget(
                                initialFilters: _currentFilters,
                                onFiltersChanged: _handleFiltersChanged,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Carousel section
                  if (state.events.isNotEmpty) ...[
                    _buildFeedSectionTitle(
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
                  _buildFeedSectionTitle(
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
                            child: _buildFeedEmptyState(
                              hasSearchQuery: _searchController.text.isNotEmpty,
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              'feed-list-${_filteredEvents.length}-${_selectedCity}',
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
                                        child: _buildEventCard(context, event),
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

  Widget _buildEventCard(BuildContext context, EventModel event) {
    final ThemeData theme = Theme.of(context);
    final categoryColor = _getCategoryColor(event.category);
    final categoryName = _getCategoryName(event.category);
    final formattedTime = DateFormat(
      'dd MMM, HH:mm',
      'ru',
    ).format(event.dateTime);

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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
                              backgroundColor: AppColors.accent.withValues(alpha: 0.92),
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
                            backgroundColor: AppColors.accent.withValues(alpha: 0.92),
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

  Widget _buildFeedSectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.dark.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedEmptyState({required bool hasSearchQuery}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              hasSearchQuery ? Icons.search_off_rounded : Icons.event_busy_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              hasSearchQuery
                  ? 'События не найдены, попробуйте другие фильтры'
                  : 'Пока нет событий. Добавьте свое!',
              style: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedErrorState(BuildContext context, String message) {
    return Container(
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Не удалось загрузить афишу',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dark.withValues(alpha: 0.86),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dark.withValues(alpha: 0.64),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    context.read<EventBloc>().add(const EventsLoadRequested());
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Обновить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Container(
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
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 12,
        ),
        children: <Widget>[
          Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.background,
            child: Container(
              height: 146,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: AppColors.surface,
                highlightColor: AppColors.background,
                child: Container(
                  height: 186,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySelection {
  const _CitySelection({
    required this.cityName,
    this.latitude,
    this.longitude,
    this.address,
  });

  final String cityName;
  final double? latitude;
  final double? longitude;
  final String? address;
}

class _CitySuggestion {
  const _CitySuggestion({
    required this.cityName,
    required this.address,
    this.latitude,
    this.longitude,
    this.fromApi = false,
  });

  final String cityName;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool fromApi;
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.cityOptions,
    required this.selectedCity,
  });

  final List<String> cityOptions;
  final String selectedCity;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final TextEditingController _citySearchController;
  final GeocodingService _geocodingService = GeocodingService();
  Timer? _debounce;

  String _query = '';
  bool _isSearching = false;
  int _requestId = 0;
  List<_CitySuggestion> _apiSuggestions = const <_CitySuggestion>[];

  @override
  void initState() {
    super.initState();
    _citySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _citySearchController.dispose();
    super.dispose();
  }

  String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  String _cityNameFromAddress(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return address;

    if (_normalizeForCompare(parts.first) == 'россия' && parts.length > 1) {
      return parts[1];
    }

    return parts.first;
  }

  Future<void> _searchRussianCities(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _apiSuggestions = const <_CitySuggestion>[];
        _isSearching = false;
      });
      return;
    }

    final int requestId = ++_requestId;
    setState(() {
      _isSearching = true;
    });

    try {
      final List<GeocodingResult> results = await _geocodingService
          .searchAddresses('$query, Россия');

      if (!mounted || requestId != _requestId) return;

      final Set<String> dedupe = <String>{};
      final List<_CitySuggestion> parsed = <_CitySuggestion>[];

      for (final result in results) {
        final cityName = _cityNameFromAddress(result.address);
        final dedupeKey =
            '${_normalizeForCompare(cityName)}:${result.latitude.toStringAsFixed(4)}:${result.longitude.toStringAsFixed(4)}';
        if (dedupe.contains(dedupeKey)) continue;
        dedupe.add(dedupeKey);

        parsed.add(
          _CitySuggestion(
            cityName: cityName,
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude,
            fromApi: true,
          ),
        );
      }

      setState(() {
        _apiSuggestions = parsed;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _apiSuggestions = const <_CitySuggestion>[];
        _isSearching = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
    });

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchRussianCities(value),
    );
  }

  List<_CitySuggestion> _localSuggestions() {
    final normalizedQuery = _normalizeForCompare(_query);
    final Iterable<String> filtered = widget.cityOptions.where((city) {
      if (_query.trim().isEmpty) return true;
      return _normalizeForCompare(city).contains(normalizedQuery);
    });

    return filtered
        .map(
          (city) => _CitySuggestion(
            cityName: city,
            address: city == 'Все города'
                ? 'Показывать события по всей России'
                : city,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<_CitySuggestion> local = _localSuggestions();
    final List<_CitySuggestion> suggestions = _query.trim().isEmpty
        ? local
        : <_CitySuggestion>[..._apiSuggestions, ...local];

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.surface.withValues(alpha: 0.98),
                  AppColors.accent.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Города России',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: AppColors.dark.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _citySearchController,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Начните вводить город: Москва, Тверь, Омск...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.dark.withValues(alpha: 0.58),
                      ),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _citySearchController.clear();
                                _onQueryChanged('');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.surface.withValues(alpha: 0.84),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: suggestions.isNotEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            final isSelected =
                                suggestion.cityName == widget.selectedCity;

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.pop(
                                    context,
                                    _CitySelection(
                                      cityName: suggestion.cityName,
                                      latitude: suggestion.latitude,
                                      longitude: suggestion.longitude,
                                      address: suggestion.address,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(alpha: 0.66),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.34)
                                          : AppColors.primary.withValues(alpha: 0.14),
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
                                    children: <Widget>[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: suggestion.fromApi
                                              ? AppColors.primary.withValues(alpha: 0.14)
                                              : AppColors.accent.withValues(alpha: 0.94),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          suggestion.fromApi
                                              ? Icons.location_city
                                              : Icons.location_on_outlined,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              suggestion.cityName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w700,
                                                color: AppColors.dark.withValues(alpha: 0.84),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              suggestion.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.dark.withValues(alpha: 0.58),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: <Widget>[
                            ListTile(
                              contentPadding: const EdgeInsets.all(0),
                              leading: Icon(
                                Icons.search_off,
                                color: AppColors.primary.withValues(alpha: 0.64),
                              ),
                              title: Text(
                                'Город не найден',
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.84),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Проверьте написание или введите другой запрос',
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
