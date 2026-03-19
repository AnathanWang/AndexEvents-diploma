import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../profile/bloc/profile_bloc.dart';
import '../../profile/bloc/profile_event.dart';
import '../../profile/bloc/profile_state.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/privacy_settings_screen.dart';
import '../../events/screens/edit_event_screen.dart';
import '../../events/bloc/event_bloc.dart';
import '../../models/event_preview.dart';
import '../../models/match_preview.dart';
import '../../widgets/match_card.dart';
import '../../../data/services/user_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/photo_gallery_sheet.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

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
  AnimationController? _entranceController;

  _ProfileMatchFilter _filter = _ProfileMatchFilter.mutual;
  bool _matchesLoading = false;
  String? _matchesError;
  String? _loadedForUserId;
  bool _showInSearch = true;
  bool _showVisitedEvents = true;
  bool _matchNotifications = true;
  String? _sanctionsLoadedForUserId;
  List<UserSanctionModel> _activeSanctions = <UserSanctionModel>[];

  final Map<_ProfileMatchFilter, List<MatchPreview>> _matchesByFilter =
      <_ProfileMatchFilter, List<MatchPreview>>{};

  @override
  void initState() {
    super.initState();
    _ensureEntranceController();

    // Загружаем профиль при открытии экрана
    context.read<ProfileBloc>().add(const ProfileLoadRequested());

    // Используем данные, которые могли прийти из HomeShell как стартовые
    _matchesByFilter[_ProfileMatchFilter.mutual] = widget.matches;
  }

  @override
  void dispose() {
    _entranceController?.dispose();
    super.dispose();
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
      late final List<UserModel> users;
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

    String formatType(String type) {
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

    final first = _activeSanctions.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD9B3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFD16A3A), size: 18),
              SizedBox(width: 8),
              Text(
                'Активные ограничения аккаунта',
                style: TextStyle(
                  color: Color(0xFF8B4D24),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatType(first.type),
            style: const TextStyle(
              color: Color(0xFF8B4D24),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            first.reason,
            style: const TextStyle(color: Color(0xFF9C643E), fontSize: 12),
          ),
          if (_activeSanctions.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'И ещё активных ограничений: ${_activeSanctions.length - 1}',
              style: const TextStyle(color: Color(0xFF9C643E), fontSize: 12),
            ),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF5965D8)
                  : const Color(0xFFF2F4FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF5965D8)
                    : const Color(0xFFD8DEFA),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF48508D),
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
          const SizedBox(width: 10),
          chip(_ProfileMatchFilter.incoming, 'Меня лайкнули'),
          const SizedBox(width: 10),
          chip(_ProfileMatchFilter.liked, 'Лайкнул'),
          const SizedBox(width: 10),
          chip(_ProfileMatchFilter.skipped, 'Пропустил'),
          const SizedBox(width: 10),
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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_matchesError != null) {
      content = Padding(
        key: ValueKey<String>('matches-error'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Не удалось загрузить список: $_matchesError',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    } else if (matches.isEmpty) {
      content = const Padding(
        key: ValueKey<String>('matches-empty'),
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Пока пусто.'),
      );
    } else {
      content = Column(
        key: ValueKey<String>('matches-$filterKey-${matches.length}'),
        children: matches
            .take(10)
            .map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
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

  bool _canAccessModeratorPanel(UserModel user) {
    final role = user.role?.trim().toUpperCase();
    return role == 'ADMIN' || role == 'MODERATOR';
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

        return RefreshIndicator(
          onRefresh: () async {
            context.read<ProfileBloc>().add(const ProfileLoadRequested());
          },
          child: ListView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
            ),
            children: <Widget>[
              _buildAnimatedSection(
                start: 0.0,
                child: _buildProfileCard(context, user, theme),
              ),
              if (_activeSanctions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAnimatedSection(start: 0.06, child: _buildSanctionsBanner()),
              ],
              const SizedBox(height: 20),
              _buildAnimatedSection(
                start: 0.12,
                child: Column(
                  children: <Widget>[
                    _buildSectionBadge(
                      title: 'Мои мероприятия',
                      caption: 'Собственные события и сохранённые планы',
                      icon: Icons.event_note_rounded,
                    ),
                    const SizedBox(height: 12),
                    if (state is ProfileLoaded && state.userEvents.isEmpty)
                      _buildEmptyStateCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Добавьте первое мероприятие',
                        subtitle:
                            'Заполните профиль события и пригласите людей.',
                      )
                    else if (state is ProfileLoaded)
                      ...state.userEvents.take(3).map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEventCard(event, context),
                        );
                      }),
                    FilledButton.tonalIcon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Добавить новое событие'),
                      style: FilledButton.styleFrom(
                        foregroundColor: const Color(0xFF404A8F),
                        backgroundColor: const Color(0xFFEAEFFF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildAnimatedSection(
                start: 0.24,
                child: Column(
                  children: <Widget>[
                    _buildSectionBadge(
                      title: 'Связи и совпадения',
                      caption: 'Последние матчи и приглашения',
                      icon: Icons.hub_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildMatchFilterChips(user),
                    const SizedBox(height: 12),
                    _buildMatchesList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (canAccessModeratorPanel)
                _buildAnimatedSection(
                  start: 0.36,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminDashboardScreen(
                            userRole: user.role ?? 'UNKNOWN',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFF2F365F), Color(0xFF4650A8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  canAccessModeratorPanel &&
                                          (user.role ?? '').trim().toUpperCase() ==
                                              'ADMIN'
                                      ? 'Панель администратора'
                                      : 'Панель модератора',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  (user.role ?? '').trim().toUpperCase() ==
                                          'ADMIN'
                                      ? 'События, пользователи, санкции и аудит'
                                      : 'Модерация событий и жалоб на них',
                                  style: TextStyle(
                                    color: Color(0xFFDFE5FF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFEFF1FF), Color(0xFFF8F9FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 168,
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
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: <Color>[
                                              Color(0xFF5E60CE),
                                              Color(0xFF8F7CFF),
                                              Color(0xFF49A3FF),
                                            ],
                                          ),
                                        ),
                                      ),
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: <Color>[
                                        Color(0xFF5E60CE),
                                        Color(0xFF8F7CFF),
                                        Color(0xFF49A3FF),
                                      ],
                                    ),
                                  ),
                                ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: 0.06),
                                  Colors.black.withValues(alpha: 0.34),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.displayName ?? user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            if (user.age != null)
                              _buildHeaderMetaChip('${user.age} лет'),
                            if (hasGender) _buildHeaderMetaChip(user.gender!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: -30,
                    child: GestureDetector(
                      onTap: () async {
                        _openPhotosGallery(user);
                      },
                      child: Container(
                        key: _avatarKey,
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ],
                          color: const Color(0xFF5E60CE),
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
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 14),
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
                        color: const Color(0xFFF6F7FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        user.bio!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                          color: const Color(0xFF353857),
                        ),
                      ),
                    ),
                  if (visibleInterests.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        ...visibleInterests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF1FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              interest,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4650A8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                        if (hiddenInterestsCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDE3FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+$hiddenInterestsCount',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF36418B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (user.socialLinks != null &&
                      user.socialLinks!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: user.socialLinks!.entries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFD9DEF8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _getSocialIcon(entry.key),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4A4D6A),
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
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openEditProfile(context),
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 16,
                          ),
                          label: const Text('Изменить'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5965D8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openPrivacySettings,
                          icon: const Icon(
                            Icons.shield_moon_outlined,
                            size: 16,
                          ),
                          label: const Text('Приватность'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            foregroundColor: const Color(0xFF3D467E),
                            side: const BorderSide(color: Color(0xFFC8D0F3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
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
      color = const Color(0xFF5E60CE);
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildEventCard(dynamic event, BuildContext context) {
    return GestureDetector(
      onTap: () async {
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
          // Обновляем профиль, если событие было изменено или удалено
          context.read<ProfileBloc>().add(const ProfileLoadRequested());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 130,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    LoggerService.error(
                      'Error loading profile event image: $url, error: $error',
                    );
                    return Container(
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF5E60CE).withValues(alpha: 0.7),
                            const Color(0xFF9370DB).withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.event, size: 48, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(event.category),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      event.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F355E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 15,
                        color: Color(0xFF7F88B3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(event.dateTime),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7F88B3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Color(0xFF7F88B3),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F88B3),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDFE5FF)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9E0FE)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF5A66D8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F355E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B83AE),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6FA)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EDFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF5965D8), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF353B67),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C84AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Спорт':
        return Colors.orange;
      case 'Музыка':
        return Colors.purple;
      case 'Искусство':
        return Colors.pink;
      case 'Еда':
        return Colors.green;
      case 'Технологии':
        return Colors.blue;
      case 'IT':
        return Colors.indigo;
      case 'Образование':
        return Colors.teal;
      case 'Развлечения':
        return Colors.amber;
      case 'Бизнес':
        return Colors.blueGrey;
      default:
        return const Color(0xFF5E60CE);
    }
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

  Future<void> _openPrivacySettings() async {
    final result = await Navigator.of(context).push<Map<String, bool>>(
      MaterialPageRoute<Map<String, bool>>(
        builder: (context) => PrivacySettingsScreen(
          showInSearch: _showInSearch,
          showVisitedEvents: _showVisitedEvents,
          matchNotifications: _matchNotifications,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _showInSearch = result['showInSearch'] ?? _showInSearch;
      _showVisitedEvents = result['showVisitedEvents'] ?? _showVisitedEvents;
      _matchNotifications = result['matchNotifications'] ?? _matchNotifications;
    });
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
      color: const Color(0xFF5E60CE),
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
