import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/user_model.dart';
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
import '../../widgets/section_header.dart';
import '../../../data/services/user_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/photo_gallery_sheet.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

enum _ProfileMatchFilter {
  mutual,
  liked,
  skipped,
  postponed,
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.events, required this.matches});

  final List<EventPreview> events;
  final List<MatchPreview> matches;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final GlobalKey _avatarKey = GlobalKey();

  _ProfileMatchFilter _filter = _ProfileMatchFilter.mutual;
  bool _matchesLoading = false;
  String? _matchesError;
  String? _loadedForUserId;
  bool _showInSearch = true;
  bool _showVisitedEvents = true;
  bool _matchNotifications = true;

  final Map<_ProfileMatchFilter, List<MatchPreview>> _matchesByFilter =
      <_ProfileMatchFilter, List<MatchPreview>>{};

  @override
  void initState() {
    super.initState();
    // Загружаем профиль при открытии экрана
    context.read<ProfileBloc>().add(const ProfileLoadRequested());

    // Используем данные, которые могли прийти из HomeShell как стартовые
    _matchesByFilter[_ProfileMatchFilter.mutual] = widget.matches;
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
        case _ProfileMatchFilter.liked:
          users = await _userService.getUsersByMatchAction(action: 'LIKE');
          break;
        case _ProfileMatchFilter.skipped:
          users = await _userService.getUsersByMatchAction(action: 'DISLIKE');
          break;
        case _ProfileMatchFilter.postponed:
          // "Отложил" = SUPER_LIKE (свайп вверх "подумаю")
          users =
              await _userService.getUsersByMatchAction(action: 'SUPER_LIKE');
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
    });
  }

  Widget _buildMatchFilterChips(UserModel currentUser) {
    Widget chip(_ProfileMatchFilter f, String label) {
      final selected = _filter == f;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) {
          if (!value) return;
          setState(() {
            _filter = f;
          });
          _loadMatchesFor(f, currentUser);
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: <Widget>[
          chip(_ProfileMatchFilter.mutual, 'Взаимные'),
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
    final canViewSensitiveInfo = _filter == _ProfileMatchFilter.mutual;

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
                padding: const EdgeInsets.only(bottom: 12),
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
              _buildProfileCard(context, user, theme),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Мои мероприятия',
                caption: 'Собственные события и сохранённые планы',
              ),
              const SizedBox(height: 12),
              if (state is ProfileLoaded && state.userEvents.isEmpty)
                const Text('Начните с создания первого события!')
              else if (state is ProfileLoaded)
                ...state.userEvents.take(3).map((event) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildEventCard(event, context),
                  );
                }),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Добавить новое событие'),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Связи и совпадения',
                caption: 'Последние матчи и приглашения',
              ),
              const SizedBox(height: 12),
              _buildMatchFilterChips(user),
              const SizedBox(height: 12),
              _buildMatchesList(),
              const SizedBox(height: 24),
              // Admin Dashboard Card
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF5E60CE),
                        Color(0xFF9370DB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const <Widget>[
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Панель модератора',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Управление событиями и пользователями',
                              style: TextStyle(
                                color: Color(0xFFE8E8FF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100), // Bottom padding
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Аватар
          Builder(
            builder: (context) => GestureDetector(
              onTap: () async {
                _openPhotosGallery(user);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    key: _avatarKey,
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF5E60CE),
                    ),
                    child: ClipOval(
                      child: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName ?? user.email,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.age != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${user.age}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF4A4D6A),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditProfile(context);
                        } else if (value == 'privacy') {
                          _openPrivacySettings();
                        }
                      },
                      itemBuilder: (context) => const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Редактировать профиль'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'privacy',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.shield_outlined),
                              SizedBox(width: 12),
                              Text('Настройки приватности'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (user.gender != null && user.gender != 'Не указывать') ...[
                  const SizedBox(height: 2),
                  Text(
                    user.gender!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (user.bio != null) ...[
                  const SizedBox(height: 4),
                  Text(user.bio!, style: theme.textTheme.bodyMedium),
                ],
                if (user.interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...user.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E60CE).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5E60CE),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
                if (user.socialLinks != null &&
                    user.socialLinks!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.socialLinks!.entries.map((entry) {
                      return InkWell(
                        onTap: () {
                          // TODO: Открыть ссылку в браузере
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
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _getSocialIcon(entry.key),
                              const SizedBox(width: 6),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4A4D6A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
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
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    LoggerService.error(
                      'Error loading profile event image: $url, error: $error',
                    );
                    return Container(
                      height: 180,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(event.category),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4D6A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(event.dateTime),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
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
