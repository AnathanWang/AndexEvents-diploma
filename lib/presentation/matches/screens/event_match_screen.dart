import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../core/services/logger_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_seen_service.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/custom_notification.dart';

import '../../../data/services/event_service.dart';

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

      LoggerService.info(
        '🟢 [EventMatchScreen] User loaded: name=${user.displayName}, onboardingCompleted=${user.isOnboardingCompleted}',
      );

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });

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

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: Color(0xFF75878A)),
      );
    } else if (!_isProfileComplete) {
      content = _buildProfileIncompleteScreen();
    } else if (_matches.isEmpty) {
      content = _buildNoEventMatchScreen();
    } else {
      content = _buildMainContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Участники',
          style: TextStyle(
            color: Color(0xFF1E2022),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1E2022)),
      ),
      body: content,
    );
  }

  Widget _buildProfileIncompleteScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF75878A).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 64,
                color: Color(0xFF75878A),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Заполните профиль для матчей',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF161823),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Добавьте имя, фото, описание о себе и интересы, чтобы найти людей с похожими увлечениями',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF9699A8)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Заполнить профиль'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75878A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventMatchScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: Color(0xFF9699A8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Совпадений пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF161823),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Посещайте мероприятия, чтобы встретить людей с похожими интересами',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF9699A8)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _refreshMatches(resetSeen: true),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Обновить подборку'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75878A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Редактировать профиль'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF75878A),
                side: const BorderSide(color: Color(0xFF75878A), width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  const Color(0xFFF4F7FF),
                  const Color(0xFFEFF3FF),
                  const Color(0xFFF7FAFF),
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
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFDCE3FB),
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
                    colors: [const Color(0xFF7C8AFF), const Color(0xFF67D2BF)],
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
                            colors: [
                              const Color(0xFF7C8AFF),
                              const Color(0xFF67D2BF),
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
                              color: const Color(0xFFE8EEFF),
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
                                    fontWeight: FontWeight.w600,
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
                                        color: const Color(0xFFF0F3FF),
                                        borderRadius: BorderRadius.circular(999),
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
