import 'package:flutter/material.dart';
import '../../../core/constants/event_messages.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_seen_service.dart';
import '../../matches/widgets/match_swipe_deck.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/custom_notification.dart';

import '../../../data/services/event_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/event_model.dart';
import 'package:intl/intl.dart';

class EventMatchScreen extends StatefulWidget {
  const EventMatchScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventMatchScreen> createState() => _EventMatchScreenState();
}

class _EventMatchScreenState extends State<EventMatchScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isEventFinished = false;
  EventModel? _event;
  UserModel? _currentUser;
  List<MatchPreview> _matches = [];

  final UserService _userService = UserService();
  final MatchSeenService _matchSeenService = MatchSeenService();
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadMatches() async {
    try {
      if (_currentUser == null) {
        LoggerService.warning(
          '🟡 [EventMatchScreen] _currentUser is null, cannot load matches',
        );
        return;
      }

      LoggerService.debug('🔵 [EventMatchScreen] Starting to load matches...');
      LoggerService.debug(
        '🔵 [EventMatchScreen] Current user location: lat=${_currentUser!.lastLatitude}, lon=${_currentUser!.lastLongitude}',
      );

      final participants = await _eventService.getEventParticipants(widget.eventId);
      
      // Фильтруем только GOING участников
      final goingParticipants = participants.where((p) => p.status == 'GOING').toList();

      LoggerService.debug(
        '🔵 [EventMatchScreen] Received ${goingParticipants.length} GOING participants',
      );

      final currentUserId = _currentUser!.id;
      final seen = await _matchSeenService.getSeenUserIds(currentUserId);
      final List<UserModel> otherUsers = [];
      
      for (final p in goingParticipants) {
        if (p.userId == currentUserId) continue;
        if (seen.contains(p.userId)) continue;
        
        try {
          final user = await _userService.getUserById(p.userId);
          otherUsers.add(user);
        } catch (e) {
             LoggerService.error('Failed to load user ${p.userId}', e);
        }
      }

      final Map<String, UserModel> uniqueUsers = <String, UserModel>{};
      for (final u in otherUsers) {
        uniqueUsers[u.id] = u;
      }

      final filteredUsers = uniqueUsers.values.toList();

      if (otherUsers.isNotEmpty) {
        LoggerService.debug(
          '🔵 [EventMatchScreen] First user: name=${otherUsers.first.displayName}, photoUrl=${otherUsers.first.photoUrl}',
        );
      }

      if (mounted) {
        setState(() {
          // Конвертируем UserModel в MatchPreview
          _matches = filteredUsers.map((user) {
            final match = MatchPreview.fromUserModel(
              user,
              currentUserInterests: _currentUser?.interests ?? const <String>[],
            );
            LoggerService.info(
              '🟢 [EventMatchScreen] Created match: name=${match.name}, age=${match.age}, photoUrl=${match.photoUrl}',
            );
            return match;
          }).toList();
          LoggerService.info(
            '🟢 [EventMatchScreen] Loaded ${_matches.length} matches into state',
          );
        });
      }
    } catch (e) {
      LoggerService.error('🔴 [EventMatchScreen] Error loading matches: $e');
    }
  }

  Future<void> _refreshMatches({bool resetSeen = false}) async {
    if (_currentUser == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (resetSeen) {
        await _matchSeenService.clear(_currentUser!.id);
      }
      await _loadMatches();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openUserProfile(MatchPreview match) async {
    UserModel userToOpen = match.userModel;

    try {
      userToOpen = await _userService.getUserById(match.id);
    } catch (e) {
      LoggerService.warning(
        '🟡 [EventMatchScreen] Не удалось загрузить свежий профиль, используем данные карточки: $e',
      );
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen.fromUser(
          user: userToOpen,
          matchPercentage: match.matchPercentage,
          commonInterests: match.commonInterests,
          canViewSensitiveInfo: false,
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LoggerService.debug('🔵 [EventMatchScreen] Loading current user...');
      final user = await _userService.getCurrentUser();
      final event = await _eventService.getEventById(widget.eventId);
      final isFinished = !_isEventStillActive(event.actualEndDateTime);

      LoggerService.info(
        '🟢 [EventMatchScreen] User loaded: name=${user.displayName}, onboardingCompleted=${user.isOnboardingCompleted}',
      );

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isEventFinished = isFinished;
          _event = event;
          _isLoading = false;
        });

        if (isFinished) {
          LoggerService.warning(
            '🟡 [EventMatchScreen] Event is finished, matches are disabled',
          );
          return;
        }

        // После загрузки текущего пользователя, загружаем матчи
        if (user.isOnboardingCompleted) {
          LoggerService.debug(
            '🔵 [EventMatchScreen] Onboarding completed, loading matches...',
          );
          await _loadMatches();
        } else {
          LoggerService.warning(
            '🟡 [EventMatchScreen] Onboarding not completed, showing incomplete screen',
          );
        }
      }
    } catch (e) {
      LoggerService.error('🔴 [EventMatchScreen] Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isProfileComplete {
    if (_currentUser == null) return false;
    // Profile is complete when onboarding is finished
    return _currentUser!.isOnboardingCompleted;
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      CustomNotification.success(context, 'Профиль успешно обновлен!');
    }
    await _loadUserData();
  }

  void _handleLike(MatchPreview match) {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }
    LoggerService.info('🟢 [_handleLike] Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleLike] Skip self-like for userId=$currentUserId');
      return;
    }

    _userService
        .sendLike(match.id, eventId: widget.eventId)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleLike] Successfully sent like for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleLike] Error sending like: $e');
        });
  }

  void _handleDislike(MatchPreview match) {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }
    LoggerService.debug('🔴 [_handleDislike] Dislike: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleDislike] Skip self-dislike for userId=$currentUserId');
      return;
    }

    _userService
        .sendDislike(match.id, eventId: widget.eventId)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleDislike] Successfully sent dislike for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleDislike] Error sending dislike: $e');
        });
  }

  void _handleSuperLike(MatchPreview match) {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }
    LoggerService.debug('🔵 [_handleSuperLike] Super Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleSuperLike] Skip self-super-like for userId=$currentUserId');
      return;
    }

    _userService
        .sendSuperLike(match.id, eventId: widget.eventId)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleSuperLike] Successfully sent super like for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleSuperLike] Error sending super like: $e');
        });
  }

  Widget _buildEmptyStateShell({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    List<Widget> actions = const <Widget>[],
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFEAF2FF),
            Color(0xFFD9E8FF),
            Color(0xFFEFF5FF),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7D8CFF).withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF63C9B6).withValues(alpha: 0.14),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFDCE4FF)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF365892).withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: iconGradient),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: iconGradient.first.withValues(alpha: 0.22),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 46, color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Color(0xFF1F3552),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF66739B),
                        height: 1.42,
                      ),
                    ),
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 28),
                      ...actions,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_isEventFinished) {
      content = _buildEventFinishedScreen();
    } else if (!_isProfileComplete) {
      content = _buildProfileIncompleteScreen();
    } else if (_matches.isEmpty) {
      content = _buildNoEventMatchScreen();
    } else {
      content = _buildMainContent();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Участники',
          style: TextStyle(
            color: Color(0xFF1F3552),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppColors.dark.withValues(alpha: 0.88),
        ),
      ),
      body: Column(
        children: [
          _buildEventHeaderCard(),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildEventHeaderCard() {
    final event = _event;
    if (event == null) return const SizedBox.shrink();

    final dateStr = DateFormat('dd.MM.yyyy', 'ru').format(event.dateTime.toLocal());
    final timeStr = DateFormat('HH:mm', 'ru').format(event.dateTime.toLocal());

    final bool finished = _isEventFinished;
    final Color pillBg = finished
        ? AppColors.dark.withValues(alpha: 0.10)
        : AppColors.primary.withValues(alpha: 0.10);
    final Color pillFg = finished
        ? AppColors.dark.withValues(alpha: 0.75)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_rounded,
              color: AppColors.primary.withValues(alpha: 0.92),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark.withValues(alpha: 0.86),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.dark.withValues(alpha: 0.58),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$dateStr • $timeStr',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pillFg.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        finished ? 'завершено' : 'идёт',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: pillFg,
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
    );
  }

  Widget _buildProfileIncompleteScreen() {
    return _buildEmptyStateShell(
      icon: Icons.favorite_border_rounded,
      iconGradient: const <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
      title: 'Заполните профиль для мэтчей',
      subtitle:
          'Добавьте имя, фото, описание о себе и интересы, чтобы находить людей с похожими увлечениями.',
      actions: <Widget>[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Заполнить профиль'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F76FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoEventMatchScreen() {
    return _buildEmptyStateShell(
      icon: Icons.search_off_rounded,
      iconGradient: const <Color>[Color(0xFF63C9B6), Color(0xFF62A9FF)],
      title: 'Совпадений пока нет',
      subtitle:
          'Посещайте мероприятия и обновляйте профиль, чтобы встретить людей с похожими интересами.',
      actions: <Widget>[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _refreshMatches(resetSeen: true),
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Обновить подборку'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F76FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Редактировать профиль'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5F76FF),
              side: const BorderSide(color: Color(0xFFBFD3FF), width: 1.6),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventFinishedScreen() {
    return _buildEmptyStateShell(
      icon: Icons.event_busy_outlined,
      iconGradient: <Color>[
        AppColors.primary.withValues(alpha: 0.70),
        AppColors.accent.withValues(alpha: 0.70),
      ],
      title: EventMessages.eventFinishedMatchesTitle,
      subtitle: EventMessages.eventFinishedMatchesDescription,
    );
  }

  bool _isEventStillActive(DateTime actualEndDateTime) {
    return actualEndDateTime.toUtc().isAfter(DateTime.now().toUtc());
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
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
          ),
        ),
        Positioned(
          top: -70,
          left: -60,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.24),
            ),
          ),
        ),
        Positioned.fill(
          child: MatchSwipeDeck(
            matches: _matches,
            topPadding: 16,
            onOpenProfile: _openUserProfile,
            onSwipe: (action, match) {
              switch (action) {
                case MatchSwipeAction.like:
                  _handleLike(match);
                  break;
                case MatchSwipeAction.dislike:
                  _handleDislike(match);
                  break;
                case MatchSwipeAction.later:
                  _handleSuperLike(match);
                  break;
                case MatchSwipeAction.info:
                  break;
              }
            },
            onDeckEmpty: () {
              if (!mounted) return;
              setState(() => _matches = <MatchPreview>[]);
            },
          ),
        ),
      ],
    );
  }
}
