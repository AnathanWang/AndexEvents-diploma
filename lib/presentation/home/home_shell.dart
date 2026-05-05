import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
import '../events/bloc/event_bloc.dart';
import '../events/bloc/event_event.dart';
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
  late final EventBloc _mapEventBloc;
  late final EventBloc _feedEventBloc;
  late final ProfileBloc _profileBloc;
  late final List<Widget> _tabs;
  bool _isCreateEventBlocked = false;
  String? _createEventBlockReason;
  bool _isFullBanActive = false;

  @override
  void initState() {
    super.initState();
    _mapEventBloc = EventBloc();
    _feedEventBloc = EventBloc();
    _profileBloc = ProfileBloc(userService: UserService());
    _tabs = <Widget>[
      BlocProvider<EventBloc>.value(
        value: _mapEventBloc,
        child: const MapExploreScreen(),
      ),
      BlocProvider<EventBloc>.value(
        value: _feedEventBloc,
        child: const EventsFeedScreen(),
      ),
      MatchesScreen(matches: _matches),
      ProfileScreen(events: _events, matches: _matches),
    ];
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
      HapticFeedback.lightImpact();
      _showFullBanMessage();
      setState(() {
        _index = 3;
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _index = index);

    // Ensure public feeds are fresh when user returns to them.
    if (index == 0) {
      _mapEventBloc.add(const EventsLoadRequested());
    }
    if (index == 1) {
      _feedEventBloc.add(const EventsLoadRequested());
    }
  }

  Future<void> _openCreateEventScreen() async {
    await _refreshCreateEventAccess();
    if (!mounted) return;

    if (_isCreateEventBlocked) {
      HapticFeedback.mediumImpact();
      final reason = _createEventBlockReason;
      final message =
          (reason != null && reason.isNotEmpty)
              ? 'Создание событий ограничено: $reason'
              : 'Создание событий временно ограничено санкцией';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    HapticFeedback.mediumImpact();
    final created = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (BuildContext context) => BlocProvider(
          create: (context) => EventBloc(),
          child: const CreateEventScreen(),
        ),
      ),
    );

    if (!mounted) return;
    if (created == true) {
      // Refresh both map "nearby" and feed lists after a new event is created.
      _mapEventBloc.add(const EventsLoadRequested());
      _feedEventBloc.add(const EventsLoadRequested());
    }
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
    _mapEventBloc.close();
    _feedEventBloc.close();
    _profileBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double floatingBarBottom = bottomInset > 0 ? bottomInset - 2 : 10;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth < 360;
    final double navItemWidth = isCompact ? 48 : 52;
    final double sideGap = isCompact ? 6 : 8;
    final double centerGap = isCompact ? 40 : 52;
    final double horizontalInset = screenWidth >= 430
      ? 52
        : screenWidth >= 390
        ? 44
        : isCompact
          ? 18
          : 30;

    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IndexedStack(
                index: _index,
                children: _tabs,
              ),
            ),
            Positioned(
              left: horizontalInset,
              right: horizontalInset,
              bottom: floatingBarBottom,
              child: _buildFloatingNavBar(
                navItemWidth: navItemWidth,
                sideGap: sideGap,
                centerGap: centerGap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar({
    required double navItemWidth,
    required double sideGap,
    required double centerGap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dark.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double rowWidth =
                        (navItemWidth * 4) + (sideGap * 2) + centerGap;
                    final double startX = (constraints.maxWidth - rowWidth) / 2;
                    final double indicatorWidth = navItemWidth + 2;

                    double itemLeft(int index) {
                      switch (index) {
                        case 0:
                          return startX;
                        case 1:
                          return startX + navItemWidth + sideGap;
                        case 2:
                          return startX + (navItemWidth * 2) + sideGap + centerGap;
                        case 3:
                          return startX + (navItemWidth * 3) + (sideGap * 2) + centerGap;
                        default:
                          return startX;
                      }
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: (itemLeft(_index) - 1).clamp(
                            0.0,
                            constraints.maxWidth - indicatorWidth,
                          ),
                          top: 1,
                          child: IgnorePointer(
                            child: Container(
                              width: indicatorWidth,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.12),
                                    AppColors.primary.withValues(alpha: 0.22),
                                    AppColors.primary.withValues(alpha: 0.12),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _buildNavItem(
                              CupertinoIcons.map,
                              'Карта',
                              0,
                              itemWidth: navItemWidth,
                            ),
                            SizedBox(width: sideGap),
                            _buildNavItem(
                              CupertinoIcons.calendar,
                              'Афиша',
                              1,
                              itemWidth: navItemWidth,
                            ),
                            SizedBox(width: centerGap),
                            _buildNavItem(
                              CupertinoIcons.heart,
                              'Матчи',
                              2,
                              itemWidth: navItemWidth,
                            ),
                            SizedBox(width: sideGap),
                            _buildNavItem(
                              CupertinoIcons.person,
                              'Профиль',
                              3,
                              itemWidth: navItemWidth,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (!_isFullBanActive)
          Positioned(
            left: 0,
            right: 0,
            top: -10,
            child: Center(
              child: GestureDetector(
                onTap: _openCreateEventScreen,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color:
                        _isCreateEventBlocked
                            ? AppColors.dark.withValues(alpha: 0.6)
                            : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isCreateEventBlocked
                                    ? AppColors.dark.withValues(alpha: 0.6)
                                    : AppColors.primary)
                                .withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isCreateEventBlocked
                        ? CupertinoIcons.lock_fill
                        : CupertinoIcons.add,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    required double itemWidth,
  }) {
    final bool isSelected = _index == index;
    return SizedBox(
      width: itemWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onNavTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.dark.withValues(alpha: 0.58),
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.dark.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
