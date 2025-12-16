import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String _selectedCity = 'Москва';
  final List<String> _cities = [
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

  void _showCityBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Выберите город',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4D6A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _cities.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Color(0xFFE0E0E0),
                  ),
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final isSelected = city == _selectedCity;
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCity = city;
                        });
                        Navigator.pop(context);
                      },
                      title: Text(
                        city,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF5E60CE)
                              : const Color(0xFF4A4D6A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF5E60CE),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleFiltersChanged(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
    });
    print('Filters changed: $filters');
  }

  void _filterEvents(List<EventModel> events, String query) {
    if (query.isEmpty) {
      _filteredEvents = events;
    } else {
      _filteredEvents = events
          .where(
            (event) =>
                event.title.toLowerCase().contains(query.toLowerCase()) ||
                event.location.toLowerCase().contains(query.toLowerCase()) ||
                event.category.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
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
          _filterEvents(state.events, _searchController.text);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<EventBloc>().add(const EventsLoadRequested());
            },
            child: ListView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 8,
              ),
              children: <Widget>[
                // Search bar
                TextField(
                  controller: _searchController,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
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
                        transitionDuration: const Duration(milliseconds: 280),
                      ),
                    );
                  },
                  onChanged: (query) {
                    setState(() {
                      _filterEvents(state.events, query);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Поиск событий...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF5E60CE),
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            color: Color(0xFF5E60CE),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filterEvents(state.events, '');
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8E8E8),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8E8E8),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF5E60CE),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // City selector and Filters in one row
                Row(
                  children: [
                    // City selector
                    GestureDetector(
                      onTap: _showCityBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF5E60CE),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedCity,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A4D6A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more,
                              color: Color(0xFF9E9E9E),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Filters
                    Expanded(
                      child: EventFiltersWidget(
                        initialFilters: _currentFilters,
                        onFiltersChanged: _handleFiltersChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                              (context, animation, secondaryAnimation, child) {
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
                          transitionDuration: const Duration(milliseconds: 280),
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
                    color: const Color(0xFF4A4D6A),
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Изображение события
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    print(
                      'Error loading feed event image: $url, error: $error',
                    );
                    return Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withOpacity(0.3),
                            categoryColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Категория
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      categoryName,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Название
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),

                  // Время
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: Color(0xFF5E60CE),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formattedTime,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Место
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: Color(0xFF5E60CE),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Участники и организатор
                  // Debug: временное логирование
                  Builder(
                    builder: (context) {
                      print('🔍 [EventCard] Событие: ${event.title}');
                      print(
                        '🔍 [EventCard] participantsCount: ${event.participantsCount}',
                      );
                      print(
                        '🔍 [EventCard] previewParticipants.length: ${event.previewParticipants.length}',
                      );
                      if (event.previewParticipants.isNotEmpty) {
                        print(
                          '🔍 [EventCard] Первый участник: ${event.previewParticipants[0].user.displayName}',
                        );
                        print(
                          '🔍 [EventCard] Первый участник photoUrl: ${event.previewParticipants[0].user.photoUrl}',
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (event.participantsCount > 0)
                    Row(
                      children: <Widget>[
                        // Аватарки участников (до 5 штук)
                        if (event.previewParticipants.isNotEmpty)
                          SizedBox(
                            width:
                                event.previewParticipants.take(5).length *
                                    18.0 +
                                14,
                            height: 28,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: List<Widget>.generate(
                                event.previewParticipants.take(5).length,
                                (int index) {
                                  final participant =
                                      event.previewParticipants[index];
                                  return Positioned(
                                    left: index * 18.0,
                                    child: participant.user.photoUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                participant.user.photoUrl!,
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundImage:
                                                          imageProvider,
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                            placeholder: (context, url) =>
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: categoryColor
                                                      .withOpacity(0.3),
                                                  child: const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: categoryColor
                                                      .withOpacity(
                                                        0.7 - index * 0.1,
                                                      ),
                                                  child: Text(
                                                    participant
                                                        .user
                                                        .displayName[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                          )
                                        : CircleAvatar(
                                            radius: 14,
                                            backgroundColor: categoryColor
                                                .withOpacity(0.7 - index * 0.1),
                                            child: Text(
                                              participant.user.displayName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          )
                        else
                          // Показываем иконку, если нет аватарок
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.group,
                              size: 16,
                              color: categoryColor,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            event.participantsCount == 1
                                ? '${event.participantsCount} участник'
                                : event.participantsCount < 5
                                ? '${event.participantsCount} участника'
                                : '${event.participantsCount} участников',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),

                  // Организатор
                  if (event.creatorName != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (event.creatorPhotoUrl != null)
                          CachedNetworkImage(
                            imageUrl: event.creatorPhotoUrl!,
                            imageBuilder: (context, imageProvider) =>
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: imageProvider,
                                ),
                            placeholder: (context, url) => const CircleAvatar(
                              radius: 16,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 16,
                              backgroundColor: categoryColor,
                              child: Text(
                                event.creatorName![0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: categoryColor,
                            child: Text(
                              event.creatorName![0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.creatorName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
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
