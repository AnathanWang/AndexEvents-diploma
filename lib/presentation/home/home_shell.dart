import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
import '../events/bloc/event_bloc.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../profile/bloc/profile_bloc.dart';
import '../../data/services/user_service.dart';
import 'sample_data.dart';
import 'screens/events_feed_screen.dart';
import 'screens/map_explore_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static final List<EventPreview> _events = SampleData.events;
  static const List<MatchPreview> _matches = SampleData.matches;

  int _index = 0;
  late final ProfileBloc _profileBloc;
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
    _profileBloc = ProfileBloc(userService: UserService());
  }

  @override
  void dispose() {
    _profileBloc.close();
    super.dispose();
  }

  void _handleFiltersChanged(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
    });
    print('Filters changed: $filters');
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            BlocProvider(
              create: (context) => EventBloc(),
              child: const MapExploreScreen(),
            ),
            BlocProvider(
              create: (context) => EventBloc(),
              child: const EventsFeedScreen(),
            ),
            MatchesScreen(matches: _matches),
            ProfileScreen(events: _events, matches: _matches),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildNavItem(Icons.map_outlined, 'Карта', 0),
                _buildNavItem(Icons.event_outlined, 'Афиша', 1),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => BlocProvider(
                          create: (context) => EventBloc(),
                          child: const CreateEventScreen(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E60CE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
                _buildNavItem(Icons.favorite_outline, 'Матчи', 2),
                _buildNavItem(Icons.person_outline, 'Профиль', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: isSelected ? const Color(0xFF5E60CE) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF5E60CE) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
