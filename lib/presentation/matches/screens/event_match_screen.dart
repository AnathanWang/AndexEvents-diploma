import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../core/constants/event_messages.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_seen_service.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/custom_notification.dart';

import '../../../data/services/event_service.dart';
import '../../../core/theme/app_colors.dart';

class EventMatchScreen extends StatefulWidget {
  const EventMatchScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventMatchScreen> createState() => _EventMatchScreenState();
}

class _EventMatchScreenState extends State<EventMatchScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isEventFinished = false;
  UserModel? _currentUser;
  List<MatchPreview> _matches = [];

  // Для анимации свайпа
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;
  double _dragDistance = 0;
  bool _isAnimating =
      false; // Флаг для предотвращения свайпов во время анимации

  // Подсказка свайпа
  bool _showHint = true;

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
          _currentIndex = 0;
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

  void _onPanStart(DragStartDetails details) {
    // Не позволяем начинать свайп во время анимации
    if (_isAnimating) {
      return;
    }

    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Не позволяем обновлять позицию во время анимации
    if (_isAnimating) {
      return;
    }

    setState(() {
      _dragPosition += details.delta;
      _dragDistance = _dragPosition.distance;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Не позволяем завершить свайп во время анимации
    if (_isAnimating) {
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Свайп вниз - показать детали (больший радиус)
    if (_dragPosition.dy > screenHeight * 0.25) {
      _openUserProfile(_matches[_currentIndex]);
      _resetDrag();
      return;
    }

    // Свайп вверх - "подумаю" (больший радиус)
    if (_dragPosition.dy < -screenHeight * 0.25) {
      _handleSuperLike();
      _animateCardOut(const Offset(0, -1000));
      return;
    }

    // Свайп влево - дизлайк (больший радиус)
    if (_dragPosition.dx < -screenWidth * 0.4) {
      _handleDislike();
      _animateCardOut(const Offset(-1000, 0));
      return;
    }

    // Свайп вправо - лайк (больший радиус)
    if (_dragPosition.dx > screenWidth * 0.4) {
      _handleLike();
      _animateCardOut(const Offset(1000, 0));
      return;
    }

    // Вернуть карточку на место с плавной анимацией
    _resetDragWithAnimation();
  }

  void _resetDrag() {
    setState(() {
      _dragPosition = Offset.zero;
      _isDragging = false;
      _dragDistance = 0;
    });
  }

  void _resetDragWithAnimation() {
    // Плавный возврат карточки с анимацией
    final startPosition = _dragPosition;
    final animationDuration = const Duration(milliseconds: 300);
    final startTime = DateTime.now();

    void animateReset() {
      if (!mounted) {
        return;
      }

      final elapsed = DateTime.now().difference(startTime);
      final progress =
          (elapsed.inMilliseconds / animationDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

      // Кривая анимации (ease-out cubic)
      final easeProgress = 1 - (1 - progress) * (1 - progress) * (1 - progress);

      setState(() {
        _dragPosition = Offset(
          startPosition.dx * (1 - easeProgress),
          startPosition.dy * (1 - easeProgress),
        );
        _dragDistance = _dragPosition.distance;
      });

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), animateReset);
      } else {
        _resetDrag();
      }
    }

    animateReset();
  }

  void _animateCardOut(Offset targetPosition) {
    // Плавная анимация вылета карточки
    _isAnimating = true;

    final startPosition = _dragPosition;
    final animationDuration = const Duration(milliseconds: 400);
    final startTime = DateTime.now();

    void animateOut() {
      if (!mounted) {
        _isAnimating = false;
        return;
      }

      final elapsed = DateTime.now().difference(startTime);
      final progress =
          (elapsed.inMilliseconds / animationDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

      // Кривая анимации (ease-in cubic)
      final easeProgress = progress * progress * progress;

      setState(() {
        _dragPosition = Offset(
          startPosition.dx +
              (targetPosition.dx - startPosition.dx) * easeProgress,
          startPosition.dy +
              (targetPosition.dy - startPosition.dy) * easeProgress,
        );
      });

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), animateOut);
      } else {
        _nextCard();
        _isAnimating = false;
      }
    }

    animateOut();
  }

  void _nextCard() {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_currentIndex < _matches.length - 1) {
        _currentIndex++;
      } else {
        // Достигли конца списка матчей: не зацикливаемся на начало
        _currentIndex = 0;
        _matches = <MatchPreview>[];
      }

      // Сброс состояния свайпа
      _dragPosition = Offset.zero;
      _isDragging = false;
      _dragDistance = 0;
    });
  }

  void _handleLike() {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }

    final match = _matches[_currentIndex];
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

  void _handleDislike() {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }

    final match = _matches[_currentIndex];
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

  void _handleSuperLike() {
    if (_isEventFinished) {
      CustomNotification.show(context, EventMessages.eventFinishedMatchesUnavailable);
      return;
    }

    final match = _matches[_currentIndex];
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

  double get _rotation {
    if (_dragPosition.dx == 0) return 0;
    const maxRotation = 0.1;
    return (_dragPosition.dx / MediaQuery.of(context).size.width) * maxRotation;
  }

  Color _getSwipeIndicatorColor() {
    if (_dragPosition.dx > 50) {
      return Colors.green;
    } else if (_dragPosition.dx < -50) {
      return Colors.red;
    } else if (_dragPosition.dy < -50) {
      return Colors.blue;
    } else if (_dragPosition.dy > 50) {
      return Colors.purple;
    }
    return Colors.transparent;
  }

  String _getSwipeIndicatorText() {
    if (_dragPosition.dx > 50) {
      return 'НРАВИТСЯ';
    } else if (_dragPosition.dx < -50) {
      return 'НЕ НРАВИТСЯ';
    } else if (_dragPosition.dy < -50) {
      return 'ЕЩЁ ПОДУМАЮ';
    } else if (_dragPosition.dy > 50) {
      return 'INFO';
    }
    return '';
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
      content = const Center(
        child: CircularProgressIndicator(color: Color(0xFF75878A)),
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF243252)),
      ),
      body: content,
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
      iconGradient: const <Color>[Color(0xFF8FA3FF), Color(0xFF63C9B6)],
      title: EventMessages.eventFinishedMatchesTitle,
      subtitle: EventMessages.eventFinishedMatchesDescription,
    );
  }

  bool _isEventStillActive(DateTime actualEndDateTime) {
    return actualEndDateTime.toUtc().isAfter(DateTime.now().toUtc());
  }

  Widget _buildMainContent() {
    if (_currentIndex >= _matches.length) {
      LoggerService.error(
        '🔴 [_buildMainContent] ERROR: _currentIndex($_currentIndex) >= _matches.length(${_matches.length})',
      );
      return _buildNoEventMatchScreen();
    }

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
              color: const Color(0xFF7D8CFF).withValues(alpha: 0.14),
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
              color: const Color(0xFF63C9B6).withValues(alpha: 0.14),
            ),
          ),
        ),
        if (_currentIndex < _matches.length - 1)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.965,
              child: Opacity(
                opacity: 0.55,
                child: _buildMatchCard(_matches[_currentIndex + 1], isTop: false),
              ),
            ),
          ),
        Positioned.fill(
          child: Transform.translate(
            offset: _dragPosition,
            child: Transform.rotate(
              angle: _rotation,
              child: _buildMatchCard(_matches[_currentIndex], isTop: true),
            ),
          ),
        ),
        if (_isDragging && _dragDistance > 30)
          Positioned.fill(child: IgnorePointer(child: _buildSwipeIndicator())),
        if (_showHint)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFDCE4FF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF5563C2),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Свайп вниз для профиля',
                          style: TextStyle(
                            color: Color(0xFF4A548F),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showHint = false;
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF7A84B8),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchCard(MatchPreview match, {required bool isTop}) {
    return GestureDetector(
      onPanStart: isTop ? _onPanStart : null,
      onPanUpdate: isTop ? _onPanUpdate : null,
      onPanEnd: isTop ? _onPanEnd : null,
      child: Container(
        margin: const EdgeInsets.only(
          top: 16,
          bottom: 22,
          left: 12,
          right: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1F4253A8),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const <Color>[
                      Color(0xFF5F76FF),
                      Color(0xFF62A9FF),
                      Color(0xFF63C9B6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              if (match.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Image.network(
                    match.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const <Color>[
                              Color(0xFF5F76FF),
                              Color(0xFF62A9FF),
                              Color(0xFF63C9B6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 22,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  match.name,
                                  style: const TextStyle(
                                    color: Color(0xFF26305E),
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (match.age != null)
                                Text(
                                  '${match.age}',
                                  style: const TextStyle(
                                    color: Color(0xFF26305E),
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFE8EEFF),
                                  Color(0xFFE7F6F2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFF75878A),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${match.matchPercentage}% совпадение',
                                  style: const TextStyle(
                                    color: Color(0xFF75878A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (match.bio != null && match.bio!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              match.bio!,
                              style: const TextStyle(
                                color: Color(0xFF4B578F),
                                fontSize: 13,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (match.commonInterests.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: match.commonInterests
                                  .take(3)
                                  .map(
                                    (interest) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.72),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFDCE4FF),
                                        ),
                                      ),
                                      child: Text(
                                        interest,
                                        style: const TextStyle(
                                          color: Color(0xFF5D67A4),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    final color = _getSwipeIndicatorColor();
    final text = _getSwipeIndicatorText();
    final opacity = math.min(_dragDistance / 100, 1.0);

    if (text.isEmpty) return const SizedBox.shrink();

    final IconData icon;
    final String caption;
    if (_dragPosition.dx > 50) {
      icon = Icons.favorite_rounded;
      caption = 'Отпустите, чтобы поставить лайк';
    } else if (_dragPosition.dx < -50) {
      icon = Icons.block_rounded;
      caption = 'Отпустите, чтобы пропустить';
    } else if (_dragPosition.dy < -50) {
      icon = Icons.bookmark_add_rounded;
      caption = 'Отпустите, чтобы вернуться позже';
    } else {
      icon = Icons.info_outline_rounded;
      caption = 'Отпустите, чтобы открыть профиль';
    }

    final panelColor = Color.lerp(
      Colors.white.withValues(alpha: 0.78),
      color.withValues(alpha: 0.20),
      0.55,
    );

    return Container(
      color: color.withValues(alpha: 0.05 * opacity),
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.14),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          text,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          style: const TextStyle(
                            color: Color(0xFF4E568A),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
