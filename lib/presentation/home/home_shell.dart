import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
import '../events/bloc/event_bloc.dart';
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
  final List<MatchPreview> _matches = <MatchPreview>[];
  final UserService _userService = UserService();

  int _index = 0;
  late final ProfileBloc _profileBloc;

  @override
  void initState() {
    super.initState();
    _profileBloc = ProfileBloc(userService: UserService());
    _loadMutualMatches();
  }

  Future<void> _loadMutualMatches() async {
    try {
      final currentUser = await _userService.getCurrentUser();
      final users = await _userService.getMutualMatches();

      if (!mounted) return;
      setState(() {
        _matches
          ..clear()
          ..addAll(
            users.map(
              (u) => MatchPreview.fromUserModel(
                u,
                currentUserInterests: currentUser.interests,
              ),
            ),
          );
      });
    } catch (_) {
      // Тихо игнорируем: UI покажет пустое состояние
      if (!mounted) return;
      setState(() {
        _matches.clear();
      });
    }
  }

  @override
  void dispose() {
    _profileBloc.close();
    super.dispose();
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
        bottomNavigationBar: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildNavItem(Icons.map_outlined, 'Карта', 0),
                    _buildNavItem(Icons.event_outlined, 'Афиша', 1),
                    const SizedBox(width: 56),
                    _buildNavItem(Icons.favorite_outline, 'Матчи', 2),
                    _buildNavItem(Icons.person_outline, 'Профиль', 3),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -8,
              child: Center(
                child: GestureDetector(
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5E60CE).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
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
