import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_seen_service.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, this.matches = const []});

  final List<MatchPreview> matches;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  UserModel? _currentUser;
  late List<MatchPreview> _matches;

  // Для анимации свайпа
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;
  double _dragDistance = 0;
  bool _isAnimating =
      false; // Флаг для предотвращения свайпов во время анимации

  // Для показа детальной информации
  bool _showDetails = false;
  bool _showHint = true;
  late AnimationController _detailsController;
  late Animation<double> _detailsAnimation;

  final UserService _userService = UserService();
  final MatchSeenService _matchSeenService = MatchSeenService();

  @override
  void initState() {
    super.initState();
    _matches = widget.matches;
    _loadUserData();
    _setupAnimations();
  }

  Future<void> _loadMatches() async {
    try {
      if (_currentUser == null) {
        debugPrint(
          '🟡 [MatchesScreen] _currentUser is null, cannot load matches',
        );
        return;
      }

      debugPrint('🔵 [MatchesScreen] Starting to load matches...');
      debugPrint(
        '🔵 [MatchesScreen] Current user location: lat=${_currentUser!.lastLatitude}, lon=${_currentUser!.lastLongitude}',
      );

      final otherUsers = await _userService.getOtherUsers(
        limit: 20,
        latitude: _currentUser!.lastLatitude,
        longitude: _currentUser!.lastLongitude,
      );

      debugPrint(
        '🔵 [MatchesScreen] Received ${otherUsers.length} users from service',
      );

      final currentUserId = _currentUser!.id;
      final seen = await _matchSeenService.getSeenUserIds(currentUserId);
      final Map<String, UserModel> uniqueUsers = <String, UserModel>{};
      for (final u in otherUsers) {
        if (u.id == currentUserId) continue;
        if (seen.contains(u.id)) continue;
        uniqueUsers[u.id] = u;
      }

      final filteredUsers = uniqueUsers.values.toList();

      if (otherUsers.isNotEmpty) {
        debugPrint(
          '🔵 [MatchesScreen] First user: name=${otherUsers.first.displayName}, photoUrl=${otherUsers.first.photoUrl}',
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
            debugPrint(
              '🟢 [MatchesScreen] Created match: name=${match.name}, age=${match.age}, photoUrl=${match.photoUrl}',
            );
            return match;
          }).toList();
          _currentIndex = 0;
          debugPrint(
            '🟢 [MatchesScreen] Loaded ${_matches.length} matches into state',
          );
        });
      }
    } catch (e) {
      debugPrint('🔴 [MatchesScreen] Error loading matches: $e');
    }
  }

  void _openUserProfile(MatchPreview match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen.fromUser(
          user: match.userModel,
          matchPercentage: match.matchPercentage,
          commonInterests: match.commonInterests,
          canViewSensitiveInfo: false,
        ),
      ),
    );
  }

  void _setupAnimations() {
    _detailsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _detailsAnimation = CurvedAnimation(
      parent: _detailsController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔵 [MatchesScreen] Loading current user...');
      final user = await _userService.getCurrentUser();

      debugPrint(
        '🟢 [MatchesScreen] User loaded: name=${user.displayName}, onboardingCompleted=${user.isOnboardingCompleted}',
      );

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });

        // После загрузки текущего пользователя, загружаем матчи
        if (user.isOnboardingCompleted) {
          debugPrint(
            '🔵 [MatchesScreen] Onboarding completed, loading matches...',
          );
          await _loadMatches();
        } else {
          debugPrint(
            '🟡 [MatchesScreen] Onboarding not completed, showing incomplete screen',
          );
        }
      }
    } catch (e) {
      debugPrint('🔴 [MatchesScreen] Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isProfileComplete {
    if (_currentUser == null) return false;

    return _currentUser!.displayName != null &&
        _currentUser!.displayName!.isNotEmpty &&
        _currentUser!.bio != null &&
        _currentUser!.bio!.isNotEmpty &&
        _currentUser!.interests.isNotEmpty;
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
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

    if (_currentIndex < _matches.length - 1) {
      _currentIndex++;
    } else {
      // Достигли конца списка матчей: не зацикливаемся на начало
      setState(() {
        _currentIndex = 0;
        _matches = <MatchPreview>[];
      });
      return;
    }

    // Сброс состояния свайпа
    _dragPosition = Offset.zero;
    _isDragging = false;
    _dragDistance = 0;
  }

  void _handleLike() {
    final match = _matches[_currentIndex];
    debugPrint('🟢 [_handleLike] Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService
        .sendLike(match.id)
        .then((_) {
          debugPrint(
            '🟢 [_handleLike] Successfully sent like for ${match.name}',
          );
        })
        .catchError((e) {
          debugPrint('🔴 [_handleLike] Error sending like: $e');
        });
  }

  void _handleDislike() {
    final match = _matches[_currentIndex];
    debugPrint('🔴 [_handleDislike] Dislike: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService
        .sendDislike(match.id)
        .then((_) {
          debugPrint(
            '🟢 [_handleDislike] Successfully sent dislike for ${match.name}',
          );
        })
        .catchError((e) {
          debugPrint('🔴 [_handleDislike] Error sending dislike: $e');
        });
  }

  void _handleSuperLike() {
    final match = _matches[_currentIndex];
    debugPrint('🔵 [_handleSuperLike] Super Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService
        .sendSuperLike(match.id)
        .then((_) {
          debugPrint(
            '🟢 [_handleSuperLike] Successfully sent super like for ${match.name}',
          );
        })
        .catchError((e) {
          debugPrint('🔴 [_handleSuperLike] Error sending super like: $e');
        });
  }

  void _hideDetailsScreen() {
    _detailsController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showDetails = false;
        });
      }
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
      return 'ПОДРОБНЕЕ';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5E60CE)),
      );
    }

    if (!_isProfileComplete) {
      return _buildProfileIncompleteScreen();
    }

    if (_matches.isEmpty) {
      return _buildNoMatchesScreen();
    }

    return Stack(
      children: [
        // Основной контент с карточками
        _buildMainContent(),

        // Детальная информация (слайд снизу)
        if (_showDetails) _buildDetailsOverlay(),
      ],
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
                color: const Color(0xFF5E60CE).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 64,
                color: Color(0xFF5E60CE),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Заполните профиль для матчей',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF4A4D6A),
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
                backgroundColor: const Color(0xFF5E60CE),
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

  Widget _buildNoMatchesScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8).withOpacity(0.5),
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
                color: Color(0xFF4A4D6A),
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
            OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Редактировать профиль'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5E60CE),
                side: const BorderSide(color: Color(0xFF5E60CE), width: 2),
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
      debugPrint(
        '🔴 [_buildMainContent] ERROR: _currentIndex($_currentIndex) >= _matches.length(${_matches.length})',
      );
      return _buildNoMatchesScreen();
    }

    return Stack(
      children: [
        // Следующая карточка (для предпросмотра)
        if (_currentIndex < _matches.length - 1)
          Positioned.fill(
            child: _buildMatchCard(_matches[_currentIndex + 1], isTop: false),
          ),

        // Текущая карточка с анимацией
        Positioned.fill(
          child: Transform.translate(
            offset: _dragPosition,
            child: Transform.rotate(
              angle: _rotation,
              child: _buildMatchCard(_matches[_currentIndex], isTop: true),
            ),
          ),
        ),

        // Индикаторы свайпа
        if (_isDragging && _dragDistance > 30)
          Positioned.fill(child: IgnorePointer(child: _buildSwipeIndicator())),

        // Подсказка о свайпе вниз (независимая от карточки)
        if (_showHint)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Свайп вниз для подробностей',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
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
                            color: Colors.white,
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
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 20,
          left: 8,
          right: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(48),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фоновый градиент
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5E60CE), Color(0xFF4ECCA3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Фото пользователя (если есть)
              if (match.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(48),
                  child: Image.network(
                    match.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF5E60CE), Color(0xFF4ECCA3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Затемнение для читаемости текста
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),

              // Информация о матче
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                        if (match.age != null)
                          Text(
                            ', ${match.age}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${match.matchPercentage}% совпадение',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (match.bio != null && match.bio!.isNotEmpty)
                      Text(
                        match.bio!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: match.commonInterests
                          .take(3)
                          .map(
                            (interest) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                interest,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
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

  Widget _buildSwipeIndicator() {
    final color = _getSwipeIndicatorColor();
    final text = _getSwipeIndicatorText();
    final opacity = math.min(_dragDistance / 100, 1.0);

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      color: color.withOpacity(0.1 * opacity),
      child: Center(
        child: Transform.rotate(
          angle: _dragPosition.dx > 0 ? -0.2 : 0.2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsOverlay() {
    final match = _matches[_currentIndex];

    return GestureDetector(
      onTap: _hideDetailsScreen,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping on content
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_detailsAnimation),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48),
                          Text(
                            match.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4D6A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _hideDetailsScreen,
                          ),
                        ],
                      ),

                      // Content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          children: [
                            // Фото профиля
                            if (_currentUser?.photoUrl != null)
                              Center(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        _currentUser!.photoUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Процент совпадения
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5E60CE),
                                      Color(0xFF4ECCA3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${match.matchPercentage}% совпадение',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // О себе
                            if (_currentUser?.bio != null) ...[
                              const Text(
                                'О себе',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A4D6A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentUser!.bio!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF4A4D6A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Общие интересы
                            const Text(
                              'Общие интересы',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A4D6A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: match.commonInterests
                                  .map(
                                    (interest) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF5E60CE,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF5E60CE,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.favorite,
                                            size: 16,
                                            color: Color(0xFF5E60CE),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            interest,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF5E60CE),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 32),

                            // Кнопки действий
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _hideDetailsScreen();
                                      _handleDislike();
                                      _animateCardOut(const Offset(-1000, 0));
                                    },
                                    icon: const Icon(Icons.close, size: 20),
                                    label: const Text('Не интересно'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                        color: Colors.red,
                                        width: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _hideDetailsScreen();
                                      _handleLike();
                                      _animateCardOut(const Offset(1000, 0));
                                    },
                                    icon: const Icon(Icons.favorite, size: 20),
                                    label: const Text('Нравится'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
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
              },
            ),
          ),
        ),
      ),
    );
  }
}
