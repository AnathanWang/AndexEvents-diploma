import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/common/custom_notification.dart';
import '../../widgets/report_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/event_service.dart';
import '../../../data/services/user_service.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/screens/real_event_detail_screen.dart';
import '../widgets/photo_gallery_sheet.dart';
import '../../widgets/common/star_rating_widget.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/utils/media_url_utils.dart';
import '../../../core/utils/match_recommendation_utils.dart';
import '../../../core/theme/app_colors.dart';
import 'package:andexevents/presentation/widgets/event_countdown_timer.dart';
// import '../../../data/services/friend_service.dart'; // Removed FriendService

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.userName,
    required this.userInitials,
    this.eventService,
    super.key,
  })  : user = null,
        commonInterests = const <String>[],
        canViewSensitiveInfo = false,
        showCommonInterestsBlock = false;

  UserProfileScreen.fromUser({
    required this.user,
    this.commonInterests = const <String>[],
    this.canViewSensitiveInfo = false,
    this.showCommonInterestsBlock = true,
    this.eventService,
    super.key,
  })  : assert(user != null),
        userName = (user!.displayName?.isNotEmpty == true)
            ? user.displayName!
            : user.email.split('@').first,
        userInitials = _initialsFrom(
          (user.displayName?.isNotEmpty == true)
              ? user.displayName!
              : user.email.split('@').first,
        );

  final String userName;
  final String userInitials;
  final UserModel? user;
  final List<String> commonInterests;
  final bool canViewSensitiveInfo;
  final bool showCommonInterestsBlock;
  final EventService? eventService;

  static String _initialsFrom(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '??';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final GlobalKey _avatarKey = GlobalKey();
  late final EventService _eventService;
  final UserService _userService = UserService();
  UserModel? _liveUser;
  UserModel? _currentUser;
  bool _isBlockedByMe = false;

  bool _eventsLoading = false;
  String? _eventsError;
  List<EventModel> _creatorEvents = <EventModel>[];
  List<EventModel> _participatedEvents = <EventModel>[];

  UserModel? get _user => _liveUser ?? widget.user;

  List<String> get _displayCommonInterests {
    final mine = _currentUser?.interests ?? const <String>[];
    final theirs = _user?.interests ?? const <String>[];
    if (mine.isNotEmpty && theirs.isNotEmpty) {
      return MatchRecommendationUtils.commonInterestLabels(
        left: mine,
        right: theirs,
      );
    }
    if (widget.commonInterests.isNotEmpty) {
      return widget.commonInterests;
    }
    return const <String>[];
  }

  String _commonInterestsTitle(int count) {
    if (count == 0) return 'Нет общих интересов';
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'У вас $count общий интерес';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'У вас $count общих интереса';
    }
    return 'У вас $count общих интересов';
  }

  ({String text, Color color}) _presenceState() {
    final lastActive = _user?.lastLocationUpdate ?? _user?.updatedAt;
    if (lastActive == null) {
      return (text: 'Был(а) недавно', color: const Color(0xFF9E9E9E));
    }

    final diff = DateTime.now().difference(lastActive.toLocal());
    if (diff.inMinutes <= 5) {
      return (text: 'Онлайн', color: Colors.green);
    }
    return (text: 'Был(а) недавно', color: const Color(0xFF9E9E9E));
  }

  @override
  void initState() {
    super.initState();
    _eventService = widget.eventService ?? EventService();
    _liveUser = widget.user;
    _refreshUser();
    _loadCurrentUser();
    _loadBlockStatus();
    _loadRecentEvents();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final me = await _userService.getCurrentUser();
      if (!mounted) return;
      setState(() => _currentUser = me);
    } catch (e) {
      LoggerService.warning(
        '[UserProfileScreen] Не удалось загрузить текущего пользователя: $e',
      );
    }
  }

  Future<void> _loadBlockStatus() async {
    final targetId = _user?.id;
    if (targetId == null || targetId.isEmpty) return;
    try {
      final ids = await _userService.getMyBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _isBlockedByMe = ids.contains(targetId);
      });
    } catch (e) {
      LoggerService.warning('[UserProfileScreen] block status load failed: $e');
    }
  }

  Future<void> _refreshUser() async {
    final id = widget.user?.id;
    if (id == null || id.isEmpty) return;

    try {
      final fresh = await _userService.getUserById(id);
      if (!mounted) return;
      setState(() {
        _liveUser = fresh;
      });
    } catch (e) {
      LoggerService.warning(
        '🟡 [UserProfileScreen] Не удалось обновить пользователя по id: $e',
      );
    }
  }

  Future<void> _loadRecentEvents() async {
    final userId = _user?.id;
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _eventsLoading = true;
      _eventsError = null;
    });

    try {
      final results = await Future.wait<List<EventModel>>(<Future<List<EventModel>>>[
        _eventService.getUserEvents(userId),
        _eventService.getUserParticipatedEvents(userId),
      ]);

      if (!mounted) return;

      final creator = List<EventModel>.from(results[0])
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final participated = List<EventModel>.from(results[1])
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      setState(() {
        _creatorEvents = creator;
        _participatedEvents = participated;
        _eventsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsLoading = false;
        _eventsError = e.toString();
      });
    }
  }

  void _openEventDetails(String eventId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider<EventBloc>(
          create: (_) => EventBloc(),
          child: RealEventDetailScreen(eventId: eventId),
        ),
      ),
    );
  }

  Widget _buildEventSection(String title, List<EventModel> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionBadge(title: title, icon: Icons.event_available),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length > 5 ? 5 : events.length,
            itemBuilder: (BuildContext context, int index) {
              final event = events[index];
              return GestureDetector(
                onTap: () => _openEventDetails(event.id),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 172,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if ((event.imageUrl ?? '').trim().isNotEmpty)
                            Image.network(
                              MediaUrlUtils.resolve(event.imageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF75878A),
                              ),
                            ),
                          if ((event.imageUrl ?? '').trim().isEmpty)
                            Container(color: const Color(0xFF75878A)),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Spacer(),
                                Text(
                                  event.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                EventCountdownTimer(expirationTime: event.actualEndDateTime, isMinimal: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEventsContent() {
    if (!(_user?.showVisitedEvents ?? true)) {
      return const SizedBox.shrink();
    }
    
    if (_eventsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_eventsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E6FA)),
          ),
          child: const Text(
            'Не удалось загрузить события',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF75878A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_creatorEvents.isEmpty && _participatedEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildSoftInfoCard('Пользователь пока не участвовал в событиях'),
      );
    }

    return Column(
      children: <Widget>[
        if (_participatedEvents.isNotEmpty)
          _buildEventSection(
            'События, в которых участвовал',
            _participatedEvents,
          ),
        if (_participatedEvents.isNotEmpty && _creatorEvents.isNotEmpty)
          const SizedBox(height: 16),
        if (_creatorEvents.isNotEmpty)
          _buildEventSection('События как создатель', _creatorEvents),
      ],
    );
  }










  Map<String, String> _normalizedSocialLinks() {
    final links = _user?.socialLinks ?? <String, dynamic>{};
    final normalized = <String, String>{};

    links.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        normalized[key.toString()] = value.toString();
      }
    });

    return normalized;
  }

  List<MapEntry<String, String>> _sortedSocialLinks(Map<String, String> links) {
    final priority = <String, int>{
      'tg': 1,
      'telegram': 1,
      'instagram': 2,
      'inst': 2,
      'vk': 3,
      'vkontakte': 3,
      'whatsapp': 4,
      'tiktok': 5,
      'website': 9,
      'phone': 10,
    };

    final entries = links.entries.toList();
    entries.sort((a, b) {
      final ap = priority[a.key.toLowerCase()] ?? 999;
      final bp = priority[b.key.toLowerCase()] ?? 999;
      if (ap != bp) return ap.compareTo(bp);
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
    return entries;
  }

  String _displaySocialName(String key) {
    switch (key.toLowerCase()) {
      case 'tg':
      case 'telegram':
        return 'Телеграм';
      case 'instagram':
      case 'inst':
        return 'Инстаграм';
      case 'vk':
      case 'vkontakte':
        return 'ВКонтакте';
      case 'tiktok':
        return 'ТикТок';
      case 'whatsapp':
        return 'WhatsApp';
      case 'website':
        return 'Сайт';
      case 'phone':
        return 'Телефон';
      default:
        if (key.isEmpty) return 'Ссылка';
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  ({IconData icon, List<Color> gradient}) _socialStyle(String key) {
    switch (key.toLowerCase()) {
      case 'tg':
      case 'telegram':
        return (
          icon: Icons.send,
          gradient: const <Color>[Color(0xFF2AABEE), Color(0xFF229ED9)],
        );
      case 'vk':
      case 'vkontakte':
        return (
          icon: Icons.group,
          gradient: const <Color>[Color(0xFF4C75A3), Color(0xFF3B5F89)],
        );
      case 'instagram':
      case 'inst':
        return (
          icon: Icons.camera_alt,
          gradient: const <Color>[
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
          ],
        );
      case 'tiktok':
        return (
          icon: Icons.music_note,
          gradient: const <Color>[Color(0xFF111111), Color(0xFF444444)],
        );
      case 'whatsapp':
        return (
          icon: Icons.chat,
          gradient: const <Color>[Color(0xFF25D366), Color(0xFF128C7E)],
        );
      case 'website':
        return (
          icon: Icons.language,
          gradient: const <Color>[Color(0xFF75878A), Color(0xFF81D8D0)],
        );
      case 'phone':
        return (
          icon: Icons.phone,
          gradient: const <Color>[Color(0xFF75878A), Color(0xFF81D8D0)],
        );
      default:
        return (
          icon: Icons.link,
          gradient: const <Color>[Color(0xFF75878A), Color(0xFF81D8D0)],
        );
    }
  }

  Widget _buildSocialLinksCard() {
    if (!widget.canViewSensitiveInfo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6FA)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              color: Color(0xFF75878A),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Соцсети доступны после взаимного лайка',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF161823),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final links = _normalizedSocialLinks();
    if (links.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6FA)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Color(0xFF75878A)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Соцсети не указаны',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF161823),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final entries = _sortedSocialLinks(links);
    return Column(
      children: entries.map((entry) {
        final style = _socialStyle(entry.key);
        final title = _displaySocialName(entry.key);
        final value = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!mounted) return;
                CustomNotification.success(
                  context,
                  'Скопировано',
                  duration: const Duration(seconds: 1),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: style.gradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3F4677),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.copy,
                      color: Color(0xFF9E9E9E),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presence = _presenceState();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: <Widget>[
          // App Bar
          SliverAppBar(
            expandedHeight: 186,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF365892).withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF243252)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: <Widget>[
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF365892).withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF243252)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (String value) {
                    if (value == 'block') {
                      _showBlockDialog();
                    } else if (value == 'report') {
                      _showReportDialog();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.block, color: Colors.orange),
                          SizedBox(width: 12),
                          Text(_isBlockedByMe ? 'Разблокировать' : 'Заблокировать'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.flag, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Пожаловаться'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    (_user?.coverImageUrl != null &&
                        _user!.coverImageUrl!.trim().isNotEmpty)
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            MediaUrlUtils.resolve(_user!.coverImageUrl!.trim()),
                          ),
                          fit: BoxFit.cover,
                        ),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            const Color(0xFF5D74FF).withValues(alpha: 0.96),
                            const Color(0xFF62A9FF).withValues(alpha: 0.92),
                            const Color(0xFF63C9B5).withValues(alpha: 0.86),
                          ],
                        ),
                      ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: -46,
                      right: -28,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -58,
                      left: -16,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDCE9FF).withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: GestureDetector(
                        onTap: _openPhotosGallery,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Container(
                              key: _avatarKey,
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  width: 4,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildAvatarPhoto(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Контент
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Имя и статус
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDCE4FF)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF365892).withValues(alpha: 0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.userName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F3552),
                                ),
                              ),
                            ),
                            if (!(_user?.hideOnlineStatus ?? false))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: presence.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: presence.color.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.circle,
                                      color: presence.color,
                                      size: 8,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      presence.text,
                                      style: TextStyle(
                                        color: presence.color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_user?.age != null)
                          Text(
                            '${_user!.age} лет',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF66739B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          _user?.bio?.isNotEmpty == true
                              ? _user!.bio!
                              : 'Еще не заполнена биография',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4B5877),
                            height: 1.45,
                          ),
                        ),
                        if (_user?.averageRating != null && _user?.eventsCreatedCount != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E6FA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StarRatingWidget(
                                  rating: _user!.averageRating!,
                                  starSize: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_user!.averageRating!.toStringAsFixed(1)} (Событий: ${_user!.eventsCreatedCount})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F3552),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if ((_user?.interests ?? const <String>[]).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSectionBadge(
                      title: 'Интересы',
                      icon: Icons.interests_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _user!.interests.map((interest) {
                        final sharedKeys = widget.showCommonInterestsBlock
                            ? _displayCommonInterests
                                .map(
                                  (shared) => shared
                                      .trim()
                                      .toLowerCase()
                                      .replaceAll('ё', 'е'),
                                )
                                .toSet()
                            : <String>{};
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sharedKeys.contains(
                              interest
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll('ё', 'е'),
                            )
                                ? const Color(0xFFE8F1FF)
                                : Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: sharedKeys.contains(
                                interest
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll('ё', 'е'),
                              )
                                  ? const Color(0xFF5F76FF).withValues(alpha: 0.35)
                                  : const Color(0xFFDCE4FF),
                            ),
                          ),
                          child: Text(
                            interest,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sharedKeys.contains(
                                interest
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll('ё', 'е'),
                              )
                                  ? const Color(0xFF243252)
                                  : const Color(0xFF4B5877),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (widget.showCommonInterestsBlock) ...[
                  // Общие интересы
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFE8F1FF), Color(0xFFE7F7F2)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFD8E7FF),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF5F76FF),
                                  Color(0xFF62A9FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _commonInterestsTitle(
                                    _displayCommonInterests.length,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF243252),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displayCommonInterests.isEmpty
                                      ? 'Добавьте интересы в профиле, чтобы видеть совпадения'
                                      : _displayCommonInterests.join(', '),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF66739B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_user?.showVisitedEvents ?? true) ...[
                  const SizedBox(height: 24),
                  // Недавние события
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSectionTitleRow(
                      title: 'Недавние события',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentEventsContent(),
                ],
                const SizedBox(height: 24),
                
                // Соцсети (доступны только после взаимного лайка)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSocialLinksCard(),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBadge({required String title, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF4F7FF), Color(0xFFEAF4FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4FF)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF5F76FF)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF243252),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4FF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF66739B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionTitleRow({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF5F76FF)),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243252),
          ),
        ),
      ],
    );
  }

  void _openPhotosGallery() {
    final user = _user;
    if (user == null) return;
    
    final allPhotos = <String>[];
    if (user.photoUrl?.isNotEmpty == true) {
      allPhotos.add(user.photoUrl!);
    }
    allPhotos.addAll(
      user.photos.where((p) => p != user.photoUrl),
    );

    if (allPhotos.isEmpty) return;

    final avatarRect = _avatarRect();

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoGallerySheet(
            photos: user.photos,
            mainPhotoUrl: user.photoUrl,
            initialAvatarSize: 124,
            sourceRect: avatarRect,
          );
        },
        transitionDuration: const Duration(milliseconds: 10),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  Rect? _avatarRect() {
    final context = _avatarKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Widget _buildAvatarPhoto() {
    final photoUrl = _user?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        MediaUrlUtils.resolve(photoUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarFallback();
        },
      );
    }
    return _buildAvatarFallback();
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        widget.userInitials,
        style: const TextStyle(
          color: Color(0xFF75878A),
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_isBlockedByMe ? 'Разблокировать пользователя?' : 'Заблокировать пользователя?'),
          content: Text(
            _isBlockedByMe
                ? 'Вы снова сможете видеть ${widget.userName} в рекомендациях.'
                : 'Вы больше не будете видеть ${widget.userName} в рекомендациях и не сможете общаться.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final targetId = _user?.id;
                if (targetId == null || targetId.isEmpty) {
                  CustomNotification.show(
                    context,
                    'Не удалось определить пользователя',
                    isError: true,
                  );
                  return;
                }

                try {
                  if (_isBlockedByMe) {
                    await _userService.unblockUser(targetId);
                  } else {
                    await _userService.blockUser(targetId);
                  }
                  if (!context.mounted) return;
                  CustomNotification.show(
                    context,
                    _isBlockedByMe
                        ? '${widget.userName} разблокирован'
                        : '${widget.userName} заблокирован',
                    duration: const Duration(seconds: 2),
                  );
                  if (!context.mounted) return;
                  setState(() {
                    _isBlockedByMe = !_isBlockedByMe;
                  });
                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                } catch (e) {
                  if (!context.mounted) return;
                  CustomNotification.show(
                    context,
                    _isBlockedByMe
                        ? 'Не удалось разблокировать: $e'
                        : 'Не удалось заблокировать: $e',
                    isError: true,
                  );
                }
              },
              child: const Text(
                'Подтвердить',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      CustomNotification.show(context, 'Ошибка авторизации', isError: true);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ReportDialog(
          targetUserId: _user?.id,
        );
      },
    );
  }
}
