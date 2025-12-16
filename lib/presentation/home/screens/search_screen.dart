import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../../data/models/event_model.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  List<EventModel> _filteredEvents = [];
  List<EventModel> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Безопасно загружаем события после построения контекста
    context.read<EventBloc>().add(const EventsLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF5F5F5),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF4A4D6A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (query) {
                        setState(() {
                          _filterEvents(_allEvents, query);
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
                  ),
                ],
              ),
            ),
            // Results list
            Expanded(
              child: BlocBuilder<EventBloc, EventState>(
                builder: (context, state) {
                  if (state is EventsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5E60CE),
                      ),
                    );
                  }

                  if (state is EventsLoaded) {
                    if (_allEvents.isEmpty) {
                      _allEvents = state.events;
                      _filterEvents(state.events, _searchController.text);
                    } else {
                      _filterEvents(_allEvents, _searchController.text);
                    }

                    if (_filteredEvents.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Начните поиск'
                                  : 'События не найдены',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9699A8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _filteredEvents.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = _filteredEvents[index];
                        return _buildEventCard(event);
                      },
                    );
                  }

                  return const Center(child: Text('Ошибка загрузки событий'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    final dateFormat = DateFormat('d MMM, HH:mm', 'ru_RU');
    final eventDate = event.dateTime;

    return GestureDetector(
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Event image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: event.imageUrl ?? '',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFE8E8E8),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5E60CE)),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFE8E8E8),
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            // Event info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4D6A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Date and time
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFF9699A8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(eventDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9699A8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Participants count
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: Color(0xFF9699A8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.participantsCount} ${_getParticipantsWord(event.participantsCount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9699A8),
                          ),
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

  String _getParticipantsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'участник';
    } else if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'участника';
    } else {
      return 'участников';
    }
  }
}
