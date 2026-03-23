import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
import '../events/bloc/event_bloc.dart';
import '../profile/bloc/profile_bloc.dart';
import '../../data/services/user_service.dart';
import '../../data/models/user_sanction_model.dart';
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
  bool _isCreateEventBlocked = false;
  String? _createEventBlockReason;
  bool _isFullBanActive = false;

  @override
  void initState() {
    super.initState();
    _profileBloc = ProfileBloc(userService: UserService());
    _loadMutualMatches();
    _refreshCreateEventAccess();
  }

  bool _isCreateSanction(UserSanctionModel sanction) {
    final type = sanction.type.trim().toUpperCase();
    return sanction.isActive &&
        (type == 'EVENT_CREATE_BAN' || type == 'FULL_BAN');
  }

  bool _isFullBanSanction(UserSanctionModel sanction) {
    final type = sanction.type.trim().toUpperCase();
    return sanction.isActive && type == 'FULL_BAN';
  }

  Future<void> _refreshCreateEventAccess() async {
    try {
      final sanctions = await _userService.getMySanctions();
      final createBan = sanctions.where(_isCreateSanction).toList();
      final fullBan = sanctions.where(_isFullBanSanction).toList();
      if (!mounted) return;

      setState(() {
        _isCreateEventBlocked = createBan.isNotEmpty;
        _createEventBlockReason =
            createBan.isEmpty ? null : createBan.first.reason.trim();
        _isFullBanActive = fullBan.isNotEmpty;
        if (_isFullBanActive) {
          _index = 3;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCreateEventBlocked = false;
        _createEventBlockReason = null;
        _isFullBanActive = false;
      });
    }
  }

  void _showFullBanMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Доступ ограничен: при FULL_BAN доступен только профиль'),
      ),
    );
  }

  void _onNavTapped(int index) {
    if (_isFullBanActive && index != 3) {
      _showFullBanMessage();
      setState(() {
        _index = 3;
      });
      return;
    }

    setState(() => _index = index);
  }

  Future<void> _openCreateEventScreen() async {
    await _refreshCreateEventAccess();
    if (!mounted) return;

    if (_isCreateEventBlocked) {
      final reason = _createEventBlockReason;
      final message =
          (reason != null && reason.isNotEmpty)
              ? 'Создание событий ограничено: $reason'
              : 'Создание событий временно ограничено санкцией';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BlocProvider(
          create: (context) => EventBloc(),
          child: const CreateEventScreen(),
        ),
      ),
    );
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
                    color: Colors.black.withValues(alpha: 0.1),
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
            if (!_isFullBanActive)
              Positioned(
                left: 0,
                right: 0,
                top: -8,
                child: Center(
                  child: GestureDetector(
                    onTap: _openCreateEventScreen,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            _isCreateEventBlocked
                                ? const Color(0xFF9FA4C8)
                                : const Color(0xFF5E60CE),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isCreateEventBlocked
                                        ? const Color(0xFF9FA4C8)
                                        : const Color(0xFF5E60CE))
                                    .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCreateEventBlocked ? Icons.block_rounded : Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
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
        onTap: () => _onNavTapped(index),
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
