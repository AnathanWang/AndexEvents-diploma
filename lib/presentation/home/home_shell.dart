import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';
import '../events/screens/create_event_screen.dart';
import '../events/bloc/event_bloc.dart';
import '../events/bloc/event_event.dart';
import '../events/bloc/event_state.dart';
import '../profile/bloc/profile_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/match/match_auto_refresh.dart';
import '../../core/match/match_refresh_bus.dart';
import '../../core/events/event_refresh_bus.dart';
import '../../data/services/location_sync_service.dart';
import '../../data/services/user_service.dart';
import '../../data/models/user_sanction_model.dart';
import '../../data/models/event_model.dart';
import '../widgets/glass_scene_stack.dart';
import 'sample_data.dart';
import 'screens/events_feed_screen.dart';
import 'screens/map_explore_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/home_floating_nav_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static final List<EventPreview> _events = SampleData.events;
  final List<MatchPreview> _matches = <MatchPreview>[];
  final UserService _userService = UserService();

  int _index = 0;
  late final EventBloc _mapEventBloc;
  late final EventBloc _feedEventBloc;
  late final ProfileBloc _profileBloc;
  late final Widget _mapTab;
  late final Widget _feedTab;
  late final Widget _matchesTab;
  late final Widget _profileTab;
  bool _isCreateEventBlocked = false;
  String? _createEventBlockReason;
  bool _isFullBanActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapEventBloc = EventBloc();
    _feedEventBloc = EventBloc();
    _profileBloc = ProfileBloc(userService: UserService());
    _feedTab = BlocProvider<EventBloc>.value(
      value: _feedEventBloc,
      child: const EventsFeedScreen(),
    );
    _mapTab = BlocProvider<EventBloc>.value(
      value: _mapEventBloc,
      child: const MapExploreScreen(),
    );
    _matchesTab = MatchesScreen(matches: _matches);
    _profileTab = ProfileScreen(events: _events, matches: _matches);
    _loadMutualMatches();
    _refreshCreateEventAccess();
    LocationSyncService.instance.start();
    MatchAutoRefresh.instance.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        LocationSyncService.instance.start();
        MatchAutoRefresh.instance.start();
        _loadMutualMatches();
        MatchRefreshBus.instance.notify();
        EventRefreshBus.instance.notify();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        LocationSyncService.instance.stop();
        MatchAutoRefresh.instance.stop();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
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

    if (index == 0 || index == 1) {
      EventRefreshBus.instance.notify();
    }
    if (index == 2 || index == 3) {
      _loadMutualMatches();
      MatchRefreshBus.instance.notify();
    }

    // Map reloads via its own viewport logic when mounted.
    if (index == 1 && _feedEventBloc.state is! EventsLoaded) {
      _feedEventBloc.add(const EventsLoadRequested());
    }
  }

  Widget _buildActiveTab() {
    return IndexedStack(
      index: _index,
      children: <Widget>[
        _mapTab,
        _feedTab,
        _matchesTab,
        _profileTab,
      ],
    );
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
    final created = await Navigator.of(context).push<EventModel?>(
      CupertinoPageRoute<EventModel?>(
        builder: (BuildContext context) => BlocProvider(
          create: (context) => EventBloc(),
          child: const CreateEventScreen(),
        ),
      ),
    );

    if (!mounted) return;
    if (created != null) {
      setState(() => _index = 1);
      _feedEventBloc.add(EventsMergeListRequested(<EventModel>[created]));
      _mapEventBloc.add(EventsMergeListRequested(<EventModel>[created]));
      EventRefreshBus.instance.notify();
      _mapEventBloc.add(
        const EventsLoadRequested(skipCache: true, silent: true, mergeWithExisting: true),
      );
      _feedEventBloc.add(
        const EventsLoadRequested(skipCache: true, silent: true),
      );
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
                currentUser: currentUser,
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
    WidgetsBinding.instance.removeObserver(this);
    LocationSyncService.instance.stop();
    MatchAutoRefresh.instance.stop();
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
        backgroundColor: AppColors.background,
        body: GlassSceneStack(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: _buildActiveTab(),
              ),
              Positioned(
                left: horizontalInset,
                right: horizontalInset,
                bottom: floatingBarBottom,
                child: HomeFloatingNavBar(
                  index: _index,
                  onTap: _onNavTapped,
                  onTapCreate: _openCreateEventScreen,
                  navItemWidth: navItemWidth,
                  sideGap: sideGap,
                  centerGap: centerGap,
                  isFullBanActive: _isFullBanActive,
                  isCreateEventBlocked: _isCreateEventBlocked,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
