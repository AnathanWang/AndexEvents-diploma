import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/logger_service.dart';
import '../../../data/services/geocoding_service.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../../data/models/event_model.dart';
import '../../widgets/event_carousel.dart';
import '../../widgets/event_filters.dart';
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (state is EventError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<EventBloc>().add(const EventsLoadRequested());
                  },
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF3F5FF), Color(0xFFFAFBFF)],
                ),
              ),
              child: ListView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 16,
                ),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFDCE3FF)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Афиша города',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F3662),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 14,
                                    color: Color(0xFF4C5BAA),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_filteredEvents.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF42509C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                            hintStyle: const TextStyle(
                              color: Color(0xFF8D95BF),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF5965D8),
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    color: const Color(0xFF5E60CE),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterEvents(_allEvents, '');
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF5965D8),
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            GestureDetector(
                              onTap: _showCityBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECF1FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xFF5E60CE),
                                      size: 17,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCity,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF3C467E),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.expand_more,
                                      color: Color(0xFF8F96B8),
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                  const SizedBox(height: 18),

                  // Carousel section
                  if (state.events.isNotEmpty) ...[
                    Text(
                      'Популярные события',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4A4D6A),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 20),
                  ],

                  // Regular events list
                  Text(
                    'Все события',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF323B69),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_filteredEvents.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Пока нет событий. Добавьте своё!'
                              : 'События не найдены',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...(_filteredEvents.map((EventModel event) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildEventCard(context, event),
                      );
                    }).toList()),
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
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFD8DFFC), width: 1),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (event.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
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
                      left: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
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
                      right: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2F355E,
                          ).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formattedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2F355E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: Color(0xFF5E60CE),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF666E99),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.participantsCount == 1
                              ? '1 участник'
                              : '${event.participantsCount} участников',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A5393),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Color(0xFF6974BB),
                      ),
                    ],
                  ),
                  if (event.creatorName != null) ...[
                    const SizedBox(height: 10),
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
                            placeholder: (context, url) => const CircleAvatar(
                              radius: 13,
                              backgroundColor: Color(0xFFE9EEFF),
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Color(0xFF5965D8),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 13,
                              backgroundColor: const Color(0xFFE9EEFF),
                              child: Text(
                                _creatorInitial(event.creatorName),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF5965D8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: const Color(0xFFE9EEFF),
                            child: Text(
                              _creatorInitial(event.creatorName),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5965D8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Организатор: ${event.creatorName!}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A81A8),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
        return Colors.purple;
      case 'sport':
        return Colors.orange;
      case 'exhibition':
        return Colors.teal;
      case 'conference':
        return Colors.blue;
      case 'party':
        return Colors.pink;
      case 'theater':
        return Colors.red;
      case 'cinema':
        return Colors.indigo;
      case 'other':
        return Colors.grey;
      default:
        return const Color(0xFF5E60CE);
    }
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFF6F8FF), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DDFB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Города России',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2F355E),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _citySearchController,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Начните вводить город: Москва, Тверь, Омск...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF5965D8),
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
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDDE3FF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDDE3FF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF5965D8),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            final isSelected =
                                suggestion.cityName == widget.selectedCity;

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
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
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFB9C6FF)
                                          : const Color(0xFFE3E8FF),
                                    ),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x08000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: suggestion.fromApi
                                              ? const Color(0xFFEAF0FF)
                                              : const Color(0xFFF1F3FA),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          suggestion.fromApi
                                              ? Icons.location_city
                                              : Icons.location_on_outlined,
                                          size: 16,
                                          color: const Color(0xFF5965D8),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
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
                                                fontSize: 15,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w700,
                                                color: const Color(0xFF2F355E),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              suggestion.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF7D85B0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF5E60CE),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: <Widget>[
                            ListTile(
                              contentPadding: const EdgeInsets.all(0),
                              leading: const Icon(
                                Icons.search_off,
                                color: Color(0xFF8790BD),
                              ),
                              title: const Text('Город не найден'),
                              subtitle: const Text(
                                'Проверьте написание или введите другой запрос',
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
