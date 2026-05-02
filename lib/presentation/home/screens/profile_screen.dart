import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../../data/models/event_model.dart';
import '../../profile/bloc/profile_bloc.dart';
import '../../profile/bloc/profile_event.dart';
import '../../profile/bloc/profile_state.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/privacy_settings_screen.dart';
import '../../events/screens/edit_event_screen.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../../models/event_preview.dart';
import '../../models/match_preview.dart';
import '../../widgets/match_card.dart';
import '../../../data/services/user_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/photo_gallery_sheet.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../../core/theme/app_colors.dart';
import 'package:andexevents/presentation/widgets/event_countdown_timer.dart';

enum _ProfileMatchFilter { mutual, incoming, liked, skipped, postponed }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.events, required this.matches});

  final List<EventPreview> events;
  final List<MatchPreview> matches;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final GlobalKey _avatarKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0);
  AnimationController? _entranceController;

  _ProfileMatchFilter _filter = _ProfileMatchFilter.mutual;
  bool _matchesLoading = false;
  String? _matchesError;
  String? _loadedForUserId;
  String? _sanctionsLoadedForUserId;
  List<UserSanctionModel> _activeSanctions = <UserSanctionModel>[];

  final Map<_ProfileMatchFilter, List<MatchPreview>> _matchesByFilter =
      <_ProfileMatchFilter, List<MatchPreview>>{};

  @override
  void initState() {
    super.initState();
    _ensureEntranceController();
    _scrollController.addListener(_onScroll);

    // Загружаем профиль при открытии экрана
    context.read<ProfileBloc>().add(const ProfileLoadRequested());

    // Используем данные, которые могли прийти из HomeShell как стартовые
    _matchesByFilter[_ProfileMatchFilter.mutual] = widget.matches;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scrollOffsetNotifier.dispose();
    _entranceController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    _scrollOffsetNotifier.value = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
  }

  void _ensureEntranceController() {
    _entranceController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  Future<void> _loadMatchesFor(
    _ProfileMatchFilter filter,
    UserModel currentUser,
  ) async {
    setState(() {
      _matchesLoading = true;
      _matchesError = null;
    });

    try {
      List<UserModel> users;
      switch (filter) {
        case _ProfileMatchFilter.mutual:
          users = await _userService.getMutualMatches();
          break;
        case _ProfileMatchFilter.incoming:
          users = await _userService.getIncomingLikes();
          break;
        case _ProfileMatchFilter.liked:
          users = await _userService.getUsersByMatchAction(action: 'LIKE');
          break;
        case _ProfileMatchFilter.skipped:
          users = await _userService.getUsersByMatchAction(action: 'DISLIKE');
          break;
        case _ProfileMatchFilter.postponed:
          // "Отложил" = SUPER_LIKE (свайп вверх "подумаю")
          users = await _userService.getUsersByMatchAction(
            action: 'SUPER_LIKE',
          );
          break;
      }

      // Один и тот же человек не должен одновременно быть во "Взаимных"
      // и в других вкладках (например, "Отложил").
      if (filter != _ProfileMatchFilter.mutual) {
        List<MatchPreview> mutualPreviews =
            _matchesByFilter[_ProfileMatchFilter.mutual] ?? <MatchPreview>[];

        if (mutualPreviews.isEmpty) {
          final mutualUsers = await _userService.getMutualMatches();
          mutualPreviews = mutualUsers
              .map(
                (u) => MatchPreview.fromUserModel(
                  u,
                  currentUserInterests: currentUser.interests,
                ),
              )
              .toList();
          if (mounted) {
            _matchesByFilter[_ProfileMatchFilter.mutual] = mutualPreviews;
          }
        }

        final mutualIds = mutualPreviews.map((m) => m.id).toSet();
        users = users.where((u) => !mutualIds.contains(u.id)).toList();
      }

      final previews = users
          .map(
            (u) => MatchPreview.fromUserModel(
              u,
              currentUserInterests: currentUser.interests,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _matchesByFilter[filter] = previews;
        _matchesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _matchesLoading = false;
        _matchesError = e.toString();
        _matchesByFilter[filter] = <MatchPreview>[];
      });
    }
  }

  void _ensureLoaded(UserModel currentUser) {
    // Загружаем один раз на пользователя при первом открытии экрана
    if (_loadedForUserId == currentUser.id) return;
    _loadedForUserId = currentUser.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMatchesFor(_filter, currentUser);
      _loadMySanctions(currentUser.id);
    });
  }

  Future<void> _loadMySanctions(String userId) async {
    if (_sanctionsLoadedForUserId == userId) return;
    _sanctionsLoadedForUserId = userId;

    try {
      final sanctions = await _userService.getMySanctions();
      if (!mounted) return;
      setState(() {
        _activeSanctions = sanctions.where((s) => s.isActive).toList();
      });
    } catch (e) {
      LoggerService.warning('[ProfileScreen] Failed to load my sanctions: $e');
    }
  }

  Widget _buildSanctionsBanner() {
    if (_activeSanctions.isEmpty) return const SizedBox.shrink();

    final first = _activeSanctions.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_rounded,
                color: AppColors.dark.withValues(alpha: 0.66),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Активные ограничения аккаунта',
                style: TextStyle(
                  color: AppColors.dark.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatSanctionType(first.type),
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            first.reason,
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
          if (_activeSanctions.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'И ещё активных ограничений: ${_activeSanctions.length - 1}',
              style: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSanctionType(String type) {
    switch (type.toUpperCase()) {
      case 'WARNING':
        return 'Предупреждение';
      case 'MUTE':
        return 'Ограничение общения';
      case 'EVENT_CREATE_BAN':
        return 'Запрет на создание событий';
      case 'FULL_BAN':
        return 'Полная блокировка действий';
      default:
        return type;
    }
  }

  Widget _buildHeaderSanctionChip() {
    if (_activeSanctions.isEmpty) return const SizedBox.shrink();

    final first = _activeSanctions.first;
    final label = _formatSanctionType(first.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.gavel_rounded, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            _activeSanctions.length > 1
                ? 'Санкция: $label +${_activeSanctions.length - 1}'
                : 'Санкция: $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchFilterChips(UserModel currentUser) {
    Widget chip(_ProfileMatchFilter f, String label) {
      final selected = _filter == f;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            if (selected) return;
            setState(() {
              _filter = f;
            });
            _loadMatchesFor(f, currentUser);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.34)
                    : AppColors.dark.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    selected
                        ? AppColors.primary
                        : AppColors.dark.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: <Widget>[
          chip(_ProfileMatchFilter.mutual, 'Взаимные'),
          const SizedBox(width: 8),
          chip(_ProfileMatchFilter.incoming, 'Меня лайкнули'),
          const SizedBox(width: 8),
          chip(_ProfileMatchFilter.liked, 'Лайкнул'),
          const SizedBox(width: 8),
          chip(_ProfileMatchFilter.skipped, 'Пропустил'),
          const SizedBox(width: 8),
          chip(_ProfileMatchFilter.postponed, 'Отложил'),
        ],
      ),
    );
  }

  Widget _buildMatchesList() {
    final matches = _matchesByFilter[_filter] ?? <MatchPreview>[];
    final canViewSensitiveInfo =
        _filter == _ProfileMatchFilter.mutual ||
        _filter == _ProfileMatchFilter.incoming;

    final String filterKey = _filter.toString();
    late final Widget content;

    if (_matchesLoading) {
      content = const Padding(
        key: ValueKey<String>('matches-loading'),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_matchesError != null) {
      content = Padding(
        key: ValueKey<String>('matches-error'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Не удалось загрузить список: $_matchesError',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    } else if (matches.isEmpty) {
      content = const Padding(
        key: ValueKey<String>('matches-empty'),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Пока пусто.'),
      );
    } else {
      content = Column(
        key: ValueKey<String>('matches-$filterKey-${matches.length}'),
        children: matches
            .take(10)
            .map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MatchCard(
                  match: match,
                  onOpenProfile: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => UserProfileScreen.fromUser(
                          user: match.userModel,
                          matchPercentage: match.matchPercentage,
                          commonInterests: match.commonInterests,
                          canViewSensitiveInfo: canViewSensitiveInfo,
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
            .toList(),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          final slide = SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation),
            child: fade,
          );
          return slide;
        },
        child: content,
      ),
    );
  }

  Widget _buildAnimatedSection({required Widget child, required double start}) {
    _ensureEntranceController();
    final animation = CurvedAnimation(
      parent: _entranceController!,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 9),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollRevealSection({
    required Widget child,
    required int order,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      child: child,
      builder: (context, offset, child) {
        final double threshold = order * 180;
        final double scrollProgress = ((offset + 320 - threshold) / 220)
            .clamp(0.0, 1.0)
            .toDouble();
        final double entrance = _entranceController?.value ?? 1;
        final double value = math.max(scrollProgress, entrance);

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
    );
  }

  bool _canAccessModeratorPanel(UserModel user) {
    final role = user.role?.trim().toUpperCase();
    return role == 'ADMIN' || role == 'MODERATOR';
  }

  Future<void> _openPrivacySettings(UserModel user) async {
    final result = await Navigator.of(context).push<Map<String, bool>>(
      MaterialPageRoute<Map<String, bool>>(
        builder: (context) => PrivacySettingsScreen(
          showVisitedEvents: user.showVisitedEvents,
          showInMatches: user.showInMatches,
          incognitoMode: user.incognitoMode,
          hideOnlineStatus: user.hideOnlineStatus,
        ),
      ),
    );

    if (result == null || !mounted) return;

    context.read<ProfileBloc>().add(
      ProfileUpdateRequested(
        showVisitedEvents: result['showVisitedEvents'],
        showInMatches: result['showInMatches'],
        incognitoMode: result['incognitoMode'],
        hideOnlineStatus: result['hideOnlineStatus'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProfileError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<ProfileBloc>().add(
                    const ProfileLoadRequested(),
                  ),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final UserModel? user = state is ProfileLoaded
            ? state.user
            : (state is ProfileUpdating ? state.user : null);

        if (user == null) {
          return const Center(child: Text('Профиль не загружен'));
        }

        _ensureLoaded(user);
        final canAccessModeratorPanel = _canAccessModeratorPanel(user);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFFEAF2FF),
                const Color(0xFFD9E8FF),
                const Color(0xFFEFF5FF),
              ],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(const ProfileLoadRequested());
            },
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 12,
              ),
              children: <Widget>[
              _buildScrollRevealSection(
                order: 0,
                child: _buildAnimatedSection(
                  start: 0.0,
                  child: _buildProfileCard(
                    context,
                    user,
                    theme,
                  ),
                ),
              ),
              if (_activeSanctions.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildScrollRevealSection(
                  order: 1,
                  child: _buildAnimatedSection(
                    start: 0.06,
                    child: _buildSanctionsBanner(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildScrollRevealSection(
                order: 2,
                child: _buildAnimatedSection(
                  start: 0.12,
                  child: _buildSurfaceSection(
                    child: Column(
                      children: <Widget>[
                        _buildSectionBadge(
                          title: 'Мероприятия',
                          caption: 'Созданные, запланированные и понравившиеся',
                          icon: Icons.event_note_rounded,
                        ),
                        const SizedBox(height: 10),
                        if (state is ProfileLoaded &&
                            state.userEvents.isEmpty &&
                            state.goingEvents.isEmpty &&
                            state.interestedEvents.isEmpty)
                          _buildEmptyStateCard(
                            icon: Icons.auto_awesome_rounded,
                            title: 'Мероприятий пока нет',
                            subtitle:
                                'Вы еще не создали и не сохранили ни одного события.',
                          )
                        else if (state is ProfileLoaded) ...[
                          _buildEventsRow('Созданные мной', state.userEvents,
                              context, isEditable: true),
                          _buildEventsRow('Я иду', state.goingEvents, context,
                              isEditable: false),
                          _buildEventsRow('Мне понравилось', state.interestedEvents,
                              context, isEditable: false),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildScrollRevealSection(
                order: 3,
                child: _buildAnimatedSection(
                  start: 0.24,
                  child: _buildSurfaceSection(
                    child: Column(
                      children: <Widget>[
                        _buildSectionBadge(
                          title: 'Связи и совпадения',
                          caption: 'Последние матчи и приглашения',
                          icon: Icons.hub_rounded,
                        ),
                        const SizedBox(height: 10),
                        _buildMatchFilterChips(user),
                        const SizedBox(height: 10),
                        _buildMatchesList(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (canAccessModeratorPanel)
                _buildScrollRevealSection(
                  order: 4,
                  child: _buildAnimatedSection(
                    start: 0.36,
                    child: _buildAdminAccessCard(context, user),
                  ),
                ),
              const SizedBox(height: 88),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurfaceSection({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    UserModel user,
    ThemeData theme,
  ) {
    final hasCover =
        user.coverImageUrl != null && user.coverImageUrl!.trim().isNotEmpty;
    final hasGender = user.gender != null && user.gender != 'Не указывать';
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;
    final visibleInterests = user.interests.take(6).toList();
    final hiddenInterestsCount =
        user.interests.length - visibleInterests.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.80),
            AppColors.accent.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          hasCover
                              ? CachedNetworkImage(
                                  imageUrl: user.coverImageUrl!.trim(),
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: <Color>[
                                              const Color(0xFF5F76FF).withValues(alpha: 0.92),
                                              const Color(0xFF62A9FF).withValues(alpha: 0.88),
                                              const Color(0xFF63C9B5).withValues(alpha: 0.74),
                                            ],
                                          ),
                                        ),
                                      ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: <Color>[
                                        const Color(0xFF5F76FF).withValues(alpha: 0.92),
                                        const Color(0xFF62A9FF).withValues(alpha: 0.88),
                                        const Color(0xFF63C9B5).withValues(alpha: 0.74),
                                      ],
                                    ),
                                  ),
                                ),
                          Positioned(
                            top: -34,
                            right: -18,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -44,
                            left: -8,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withValues(alpha: 0.20),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.white.withValues(alpha: 0.04),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.24),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    right: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.displayName ?? user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: <Widget>[
                            if (user.age != null)
                              _buildHeaderMetaChip('${user.age} лет'),
                            if (hasGender) _buildHeaderMetaChip(user.gender!),
                            if (_activeSanctions.isNotEmpty)
                              _buildHeaderSanctionChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: -26,
                    child: GestureDetector(
                      onTap: () async {
                        _openPhotosGallery(user);
                      },
                      child: Container(
                        key: _avatarKey,
                        width: 74,
                        height: 74,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF5F76FF),
                              Color(0xFF62A9FF),
                              Color(0xFF63C9B5),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.dark.withValues(alpha: 0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              (user.photoUrl != null &&
                                  user.photoUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: user.photoUrl!.trim(),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    LoggerService.error(
                                      '🔴 [ProfileScreen] Ошибка загрузки аватара: $error',
                                    );
                                    return _buildProfileAvatarFallback(user);
                                  },
                                )
                              : _buildProfileAvatarFallback(user),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 34, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (hasBio)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        user.bio!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                          color: AppColors.dark.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  if (visibleInterests.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ...visibleInterests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.primary.withValues(alpha: 0.16),
                                  AppColors.accent.withValues(alpha: 0.66),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.dark.withValues(alpha: 0.76),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                        if (hiddenInterestsCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              '+$hiddenInterestsCount',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (user.socialLinks != null &&
                      user.socialLinks!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: user.socialLinks!.entries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final entry = user.socialLinks!.entries.elementAt(
                            index,
                          );
                          return InkWell(
                            onTap: () {
                              CustomNotification.show(
                                context,
                                '${entry.key}: ${entry.value}',
                                isError: false,
                                duration: const Duration(seconds: 2),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _getSocialIcon(entry.key),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.dark.withValues(alpha: 0.82),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Быстрые действия',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF243252),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tileWidth = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          SizedBox(
                            width: tileWidth,
                            child: _buildQuickActionTile(
                              icon: Icons.auto_fix_high_rounded,
                              title: 'Изменить профиль',
                              subtitle: 'Фото, био и интересы',
                              onTap: () => _openEditProfile(context),
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _buildQuickActionTile(
                              icon: Icons.shield_moon_outlined,
                              title: 'Приватность',
                              subtitle: 'Кто видит ваш профиль',
                              onTap: () => _openPrivacySettings(user),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.72),
                AppColors.accent.withValues(alpha: 0.52),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF243252),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF66739B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminAccessCard(BuildContext context, UserModel user) {
    final bool isAdmin = (user.role ?? '').trim().toUpperCase() == 'ADMIN';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(userRole: user.role ?? 'UNKNOWN'),
            ),
          );
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.76),
                AppColors.accent.withValues(alpha: 0.58),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isAdmin ? 'Панель администратора' : 'Панель модератора',
                      style: TextStyle(
                        color: const Color(0xFF243252),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAdmin
                          ? 'События, пользователи, санкции и аудит'
                          : 'Модерация событий и жалоб на них',
                      style: TextStyle(
                        color: const Color(0xFF66739B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMetaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _getSocialIcon(String platform) {
    final platformLower = platform.toLowerCase();
    IconData icon;
    Color color;

    if (platformLower.contains('instagram')) {
      icon = Icons.camera_alt;
      color = const Color(0xFFE4405F);
    } else if (platformLower.contains('telegram')) {
      icon = Icons.send;
      color = const Color(0xFF0088cc);
    } else if (platformLower.contains('vk') ||
        platformLower.contains('вконтакте')) {
      icon = Icons.group;
      color = const Color(0xFF0077FF);
    } else if (platformLower.contains('facebook')) {
      icon = Icons.facebook;
      color = const Color(0xFF1877F2);
    } else if (platformLower.contains('twitter') ||
        platformLower.contains('x')) {
      icon = Icons.alternate_email;
      color = Colors.black;
    } else {
      icon = Icons.link;
      color = const Color(0xFF75878A);
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildEventsRow(String title, List<dynamic> events, BuildContext context, {required bool isEditable}) {
    if (events.isEmpty) return const SizedBox.shrink();

    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double listHeight = (166 + ((textScale - 1) * 20)).clamp(166, 188).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6, left: 12, right: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.dark.withValues(alpha: 0.82),
            ),
          ),
        ),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            clipBehavior: Clip.none,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _buildCompactEventCard(events[index], context, isEditable: isEditable);
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCompactEventCard(dynamic event, BuildContext context, {required bool isEditable}) {
    final imageUrl = event is EventModel ? event.imageUrl : (event as dynamic).imageUrl?.toString();
    final title = event is EventModel ? event.title : (event as dynamic).title;
    final dateTime = event is EventModel ? event.dateTime : (event as dynamic).date;
    final id = event is EventModel ? event.id : (event as dynamic).id;
    final actualExpiration = event is EventModel ? event.actualEndDateTime : (event as dynamic).actualExpirationTime;
    
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    
    return GestureDetector(
      onTap: () async {
        if (isEditable) {
           final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => EventBloc(),
                child: EditEventScreen(event: event),
              ),
            ),
          );
          if (result == true && context.mounted) {
            context.read<ProfileBloc>().add(const ProfileLoadRequested());
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => EventBloc(),
                child: RealEventDetailScreen(
                  eventId: id,
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.74),
            AppColors.accent.withValues(alpha: 0.54),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 84,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(
                    color: AppColors.surface.withValues(alpha: 0.42),
                  ),
                  errorWidget: (context, _, __) => _buildFallbackImageCompact(),
                ),
              )
            else
              _buildFallbackImageCompact(),
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 2, right: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark.withValues(alpha: 0.84),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: AppColors.dark.withValues(alpha: 0.56),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(dateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.dark.withValues(alpha: 0.56),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  EventCountdownTimer(expirationTime: actualExpiration, isMinimal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImageCompact() {
    return Container(
      width: double.infinity,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.event_outlined,
          color: AppColors.dark.withValues(alpha: 0.32),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSectionBadge({
    required String title,
    required String caption,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.72),
            AppColors.accent.withValues(alpha: 0.48),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.dark.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.dark.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}, ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _openPhotosGallery(UserModel user) {
    if (user.photoUrl == null && user.photos.isEmpty) return;

    final avatarRect = _avatarRect();

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (BuildContext context, _, __) {
          return PhotoGallerySheet(
            photos: user.photos,
            mainPhotoUrl: user.photoUrl,
            initialAvatarSize: 64,
            sourceRect: avatarRect,
          );
        },
        transitionDuration: const Duration(milliseconds: 10),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final profileBloc = context.read<ProfileBloc>();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => BlocProvider.value(
          value: profileBloc,
          child: const EditProfileScreen(),
        ),
      ),
    );
    if (result == true && context.mounted) {
      CustomNotification.success(context, 'Профиль успешно обновлен!');
    }
  }

  Rect? _avatarRect() {
    final context = _avatarKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Widget _buildProfileAvatarFallback(UserModel user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        user.displayName?.isNotEmpty == true
            ? user.displayName![0].toUpperCase()
            : user.email[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
