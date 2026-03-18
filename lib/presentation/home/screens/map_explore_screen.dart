import 'package:flutter/material.dart';
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
import '../screens/search_screen.dart';

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  late DraggableScrollableController _scrollableController;
  late TextEditingController _searchController;
  YandexMapController? _mapController;
  Point? _currentUserLocation;
  double _sheetSize = 0.25; // Текущий размер bottom sheet
  List<EventModel> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _scrollableController = DraggableScrollableController();
    _searchController = TextEditingController();

    // Слушаем изменения размера bottom sheet
    _scrollableController.addListener(() {
      if (mounted) {
        setState(() {
          _sheetSize = _scrollableController.size;
        });
      }
    });

    context.read<EventBloc>().add(const EventsLoadRequested());
  }

  @override
  void dispose() {
    _scrollableController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _restoreSheet() {
    _scrollableController.animateTo(
      0.25,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

        return Stack(
          children: [
            // Full screen map
            YandexMapWidget(
              events: events,
              isInteractive: true,
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
              },
              onUserLocationUpdated: (location) {
                setState(() {
                  _currentUserLocation = location;
                });
              },
              onEventMarkerTapped: (event) {
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

            // Search bar at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E7FF),
                        width: 1,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
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
                                        initialQuery: _searchController.text,
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
                      onChanged: (query) {
                        setState(() {
                          _filterEvents(events, query);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Поиск по карте',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8D95BF),
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF5965D8),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                color: const Color(0xFF5965D8),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _filterEvents(events, '');
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF5965D8),
                            width: 1.6,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map control buttons (bottom right for one-hand use)
            // Позиция адаптируется к размеру bottom sheet
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              right: 16,
              bottom: MediaQuery.of(context).size.height * _sheetSize + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // My location button
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 2,
                    child: InkWell(
                      onTap: _centerOnUserLocation,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE2FF)),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xFF5E60CE),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom in button
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        _mapController?.moveCamera(
                          CameraUpdate.zoomIn(),
                          animation: const MapAnimation(
                            type: MapAnimationType.smooth,
                            duration: 0.3,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE2FF)),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Color(0xFF5E60CE),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom out button
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        _mapController?.moveCamera(
                          CameraUpdate.zoomOut(),
                          animation: const MapAnimation(
                            type: MapAnimationType.smooth,
                            duration: 0.3,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE2FF)),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: Color(0xFF5E60CE),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Open events button (when collapsed)
            // Показывается только когда sheet свернут
            if (_sheetSize < 0.3)
              Positioned(
                bottom: 20,
                left: 16,
                child: FloatingActionButton.extended(
                  onPressed: _restoreSheet,
                  backgroundColor: const Color(0xFF2F355E),
                  elevation: 8,
                  icon: const Icon(Icons.view_agenda_rounded, size: 18),
                  label: const Text(
                    'Список',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            // Draggable bottom sheet with events
            DraggableScrollableSheet(
              controller: _scrollableController,
              initialChildSize: 0.25,
              minChildSize: 0.0,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.0, 0.25, 0.95],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(color: const Color(0xFFDCE3FF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 20,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      GestureDetector(
                        onVerticalDragUpdate: (details) {
                          _scrollableController.animateTo(
                            (_scrollableController.size.clamp(0.0, 1.0)) -
                                details.delta.dy / 500,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.linear,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 16),
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Header with title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'События рядом',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2F355E),
                                    ),
                              ),
                            ),
                            Text(
                              '${_filteredEvents.length}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Events list
                      Expanded(
                        child: _filteredEvents.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isNotEmpty
                                      ? 'События не найдены'
                                      : 'Нет событий рядом',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                itemCount: _filteredEvents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  return _buildEventCard(event, context);
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (context) => EventBloc(),
              child: RealEventDetailScreen(eventId: event.id),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE3FF), width: 1),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Event image
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  width: 108,
                  height: 108,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 108,
                    height: 108,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 108,
                      height: 108,
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
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor.withValues(alpha: 0.3),
                      categoryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),

            // Event info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8088B6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2F355E),
                      ),
                    ),

                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: Color(0xFF7C85B5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7C85B5),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Color(0xFF6974BB),
                        ),
                      ],
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
