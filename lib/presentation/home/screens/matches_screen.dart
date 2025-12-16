import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/edit_profile_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.matches});

  final List<MatchPreview> matches;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  UserModel? _currentUser;

  // Для анимации свайпа
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;
  double _dragDistance = 0;

  // Для показа детальной информации
  bool _showDetails = false;
  late AnimationController _detailsController;
  late Animation<double> _detailsAnimation;

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupAnimations();
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
      final user = await _userService.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
      _dragDistance = _dragPosition.distance;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Свайп вниз - показать детали
    if (_dragPosition.dy > 100) {
      _showDetailsScreen();
      _resetDrag();
      return;
    }

    // Свайп вверх - "подумаю"
    if (_dragPosition.dy < -100) {
      _handleSuperLike();
      _animateCardOut(const Offset(0, -1000));
      return;
    }

    // Свайп влево - дизлайк
    if (_dragPosition.dx < -screenWidth * 0.3) {
      _handleDislike();
      _animateCardOut(const Offset(-1000, 0));
      return;
    }

    // Свайп вправо - лайк
    if (_dragPosition.dx > screenWidth * 0.3) {
      _handleLike();
      _animateCardOut(const Offset(1000, 0));
      return;
    }

    // Вернуть карточку на место
    _resetDrag();
  }

  void _resetDrag() {
    setState(() {
      _dragPosition = Offset.zero;
      _isDragging = false;
      _dragDistance = 0;
    });
  }

  void _animateCardOut(Offset targetPosition) {
    // TODO: Добавить плавную анимацию вылета карточки
    setState(() {
      _dragPosition = targetPosition;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    setState(() {
      if (_currentIndex < widget.matches.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
      _resetDrag();
    });
  }

  void _handleLike() {
    debugPrint('Like: ${widget.matches[_currentIndex].name}');
    // TODO: Отправить лайк на сервер
  }

  void _handleDislike() {
    debugPrint('Dislike: ${widget.matches[_currentIndex].name}');
    // TODO: Отправить дизлайк на сервер
  }

  void _handleSuperLike() {
    debugPrint('Super Like: ${widget.matches[_currentIndex].name}');
    // TODO: Отправить супер-лайк на сервер
  }

  void _showDetailsScreen() {
    setState(() {
      _showDetails = true;
    });
    _detailsController.forward();
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

    if (widget.matches.isEmpty) {
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
    return Stack(
      children: [
        // Следующая карточка (для предпросмотра)
        if (_currentIndex < widget.matches.length - 1)
          Positioned.fill(
            child: _buildMatchCard(
              widget.matches[_currentIndex + 1],
              isTop: false,
            ),
          ),

        // Текущая карточка с анимацией
        Positioned.fill(
          child: Transform.translate(
            offset: _dragPosition,
            child: Transform.rotate(
              angle: _rotation,
              child: _buildMatchCard(
                widget.matches[_currentIndex],
                isTop: true,
              ),
            ),
          ),
        ),

        // Индикаторы свайпа
        if (_isDragging && _dragDistance > 30)
          Positioned.fill(child: IgnorePointer(child: _buildSwipeIndicator())),

        // Кнопки действий внизу
        Positioned(bottom: 40, left: 0, right: 0, child: _buildActionButtons()),
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
          top: MediaQuery.of(context).padding.top,
          bottom: isTop ? 0 : 20,
          left: isTop ? 0 : 10,
          right: isTop ? 0 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isTop ? 0 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTop ? 0 : 20),
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
              if (_currentUser?.photoUrl != null)
                Image.network(
                  _currentUser!.photoUrl!,
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
                bottom: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
                      ),
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
                    Text(
                      match.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
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

              // Подсказка о свайпе вниз
              if (isTop)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Свайп вниз для подробностей',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Дизлайк
        _buildActionButton(
          icon: Icons.close,
          color: Colors.red,
          size: 56,
          onTap: () {
            _handleDislike();
            _animateCardOut(const Offset(-1000, 0));
          },
        ),
        const SizedBox(width: 20),

        // Супер лайк
        _buildActionButton(
          icon: Icons.star,
          color: Colors.blue,
          size: 48,
          onTap: () {
            _handleSuperLike();
            _animateCardOut(const Offset(0, -1000));
          },
        ),
        const SizedBox(width: 20),

        // Лайк
        _buildActionButton(
          icon: Icons.favorite,
          color: Colors.green,
          size: 64,
          onTap: () {
            _handleLike();
            _animateCardOut(const Offset(1000, 0));
          },
        ),
        const SizedBox(width: 20),

        // Подробнее
        _buildActionButton(
          icon: Icons.info_outline,
          color: Color(0xFF5E60CE),
          size: 48,
          onTap: _showDetailsScreen,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }

  Widget _buildDetailsOverlay() {
    final match = widget.matches[_currentIndex];

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
