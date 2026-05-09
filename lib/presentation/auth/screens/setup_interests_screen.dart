import 'package:flutter/material.dart';

import '../../../data/services/user_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'setup_location_screen.dart';
import '../widgets/auth_glass_card.dart';
import '../widgets/auth_glass_scaffold.dart';

/// Экран 2: Выбор интересов
/// Минимум 3 интереса для продолжения
class SetupInterestsScreen extends StatefulWidget {
  const SetupInterestsScreen({super.key});

  @override
  State<SetupInterestsScreen> createState() => _SetupInterestsScreenState();
}

class _SetupInterestsScreenState extends State<SetupInterestsScreen> {
  final Set<String> _selectedInterests = <String>{};
  final UserService _userService = UserService();
  bool _isLoading = false;

  final List<InterestItem> _interests = <InterestItem>[
    const InterestItem(
      name: 'Музыка',
      icon: Icons.music_note_rounded,
      colors: <Color>[Color(0xFF6B84FF), Color(0xFF4EA5FF)],
    ),
    const InterestItem(
      name: 'Спорт',
      icon: Icons.sports_soccer_rounded,
      colors: <Color>[Color(0xFF42B7D8), Color(0xFF62C9B5)],
    ),
    const InterestItem(
      name: 'Кино',
      icon: Icons.movie_creation_rounded,
      colors: <Color>[Color(0xFF7B7EFF), Color(0xFF8FA3FF)],
    ),
    const InterestItem(
      name: 'IT',
      icon: Icons.computer_rounded,
      colors: <Color>[Color(0xFF4C98FF), Color(0xFF63B7FF)],
    ),
    const InterestItem(
      name: 'Искусство',
      icon: Icons.palette_rounded,
      colors: <Color>[Color(0xFF62C9B5), Color(0xFF84D7C8)],
    ),
    const InterestItem(
      name: 'Книги',
      icon: Icons.menu_book_rounded,
      colors: <Color>[Color(0xFF6D86FF), Color(0xFF91A6FF)],
    ),
    const InterestItem(
      name: 'Еда',
      icon: Icons.restaurant_rounded,
      colors: <Color>[Color(0xFF44A7FF), Color(0xFF79C4FF)],
    ),
    const InterestItem(
      name: 'Путешествия',
      icon: Icons.flight_takeoff_rounded,
      colors: <Color>[Color(0xFF54B5F7), Color(0xFF62C9B5)],
    ),
    const InterestItem(
      name: 'Фотография',
      icon: Icons.camera_alt_rounded,
      colors: <Color>[Color(0xFF7281FF), Color(0xFF61B5FF)],
    ),
    const InterestItem(
      name: 'Мода',
      icon: Icons.checkroom_rounded,
      colors: <Color>[Color(0xFF5E98FF), Color(0xFF8EB2FF)],
    ),
    const InterestItem(
      name: 'Танцы',
      icon: Icons.album_rounded,
      colors: <Color>[Color(0xFF61C7C2), Color(0xFF74D6AF)],
    ),
    const InterestItem(
      name: 'Игры',
      icon: Icons.videogame_asset_rounded,
      colors: <Color>[Color(0xFF6880FF), Color(0xFF4EAEFF)],
    ),
  ];

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  bool get _canContinue => _selectedInterests.length >= 3;

  Future<void> _handleNext() async {
    if (!_canContinue) {
      CustomNotification.error(context, 'Выберите минимум 3 интереса');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.updateProfile(
        interests: _selectedInterests.toList(),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const SetupLocationScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomNotification.error(context, 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF273043)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF637DFF),
                                  Color(0xFF6AA8FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF637DFF),
                                  Color(0xFF6AA8FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCE4FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Что вам интересно?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2441),
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Подберем события и людей точнее, если вы отметите хотя бы три интереса.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5D668C),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthGlassCard(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _canContinue
                                    ? <Color>[
                                        const Color(0xFFDEE7FF),
                                        const Color(0xFFDDF4EF),
                                      ]
                                    : <Color>[
                                        Colors.white,
                                        const Color(0xFFF3F7FF),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _canContinue
                                    ? const Color(0xFFB8D4FF)
                                    : const Color(0xFFE3EAFB),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _canContinue
                                          ? const <Color>[
                                              Color(0xFF63C9B5),
                                              Color(0xFF6AA8FF),
                                            ]
                                          : const <Color>[
                                              Color(0xFFCAD9FF),
                                              Color(0xFFD7E6FF),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _canContinue
                                        ? Icons.check_rounded
                                        : Icons.interests_rounded,
                                    color: _canContinue
                                        ? Colors.white
                                        : const Color(0xFF6173A5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _canContinue
                                            ? 'Отличный набор'
                                            : 'Нужно минимум 3 интереса',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF243252),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Выбрано: ${_selectedInterests.length} из 3 минимум',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF66739B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _interests.map((InterestItem interest) {
                              final bool isSelected = _selectedInterests.contains(
                                interest.name,
                              );

                              return _InterestTile(
                                interest: interest,
                                isSelected: isSelected,
                                onTap: _isLoading
                                    ? null
                                    : () => _toggleInterest(interest.name),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE1E9FF),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF5F76FF),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Интересы можно будет изменить позже в профиле.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: Color(0xFF66739B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  Color(0xFF5F76FF),
                                  Color(0xFF62A9FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF5F76FF).withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Продолжить',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.interest,
    required this.isSelected,
    required this.onTap,
  });

  final InterestItem interest;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 64) / 2,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        interest.colors.first.withValues(alpha: 0.16),
                        interest.colors.last.withValues(alpha: 0.08),
                      ],
                    )
                  : const LinearGradient(
                      colors: <Color>[Colors.white, Color(0xFFF7FAFF)],
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? interest.colors.first.withValues(alpha: 0.55)
                    : const Color(0xFFE3EAFB),
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: interest.colors.first.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: interest.colors),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    interest.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    interest.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF243252)
                          : const Color(0xFF4B5877),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: interest.colors.first,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InterestItem {
  const InterestItem({
    required this.name,
    required this.icon,
    required this.colors,
  });

  final String name;
  final IconData icon;
  final List<Color> colors;
}
