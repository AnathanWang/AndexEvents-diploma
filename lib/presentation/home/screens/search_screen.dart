import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_event.dart';
import '../../events/bloc/event_state.dart';
import '../../../data/models/event_model.dart';
import '../../../core/theme/app_colors.dart';
import 'search/search_widgets.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventBloc>().add(const EventsLoadRequested());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterEvents(List<EventModel> events, String query) {
    final normalized = query.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredEvents = events;
    } else {
      _filteredEvents = events
          .where(
            (event) =>
                event.title.toLowerCase().contains(normalized) ||
                event.description.toLowerCase().contains(normalized) ||
                event.location.toLowerCase().contains(normalized) ||
                event.category.toLowerCase().contains(normalized),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SearchHeader(
              controller: _searchController,
              onBack: () => Navigator.pop(context),
              onChanged: (query) {
                setState(() {
                  _filterEvents(_allEvents, query);
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() {
                  _filterEvents(_allEvents, '');
                });
              },
            ),
            // Results list
            Expanded(
              child: BlocBuilder<EventBloc, EventState>(
                builder: (context, state) {
                  if (state is EventsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF75878A),
                      ),
                    );
                  }

                  if (state is EventsLoaded) {
                    if (!identical(_allEvents, state.events)) {
                      _allEvents = state.events;
                    }
                    _filterEvents(_allEvents, _searchController.text);

                    if (_filteredEvents.isEmpty) {
                      return SearchEmptyState(query: _searchController.text);
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
                        return SearchEventCard(event: event);
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
}
