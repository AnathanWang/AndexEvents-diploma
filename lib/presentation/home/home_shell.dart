import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_titleForIndex(_index), style: theme.textTheme.titleMedium),
        centerTitle: false,
        actions: _index == 3
            ? <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => BlocProvider.value(
                            value: _profileBloc,
                            child: const EditProfileScreen(),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFF5E60CE),
                      child: Icon(Icons.settings_outlined, color: Colors.white),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          MapExploreScreen(events: _events),
          EventsFeedScreen(events: _events),
          MatchesScreen(matches: _matches),
          ProfileScreen(events: _events, matches: _matches),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.map_outlined, 'Карта', 0),
            _buildNavItem(Icons.event_outlined, 'Афиша', 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.favorite_outline, 'Матчи', 2),
            _buildNavItem(Icons.person_outline, 'Профиль', 3),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const CreateEventScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  String _titleForIndex(int index) {
    return <String>[
      'Карта событий',
      'Афиша города',
      'Совпадения',
      'Мой профиль',
    ][index];
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
