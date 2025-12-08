import 'package:flutter/material.dart';
import '../../../data/services/user_service.dart';
import 'setup_location_screen.dart';

/// Экран 2: Выбор интересов
/// Минимум 3 интереса для продолжения
class SetupInterestsScreen extends StatefulWidget {
  const SetupInterestsScreen({super.key});

  @override
  State<SetupInterestsScreen> createState() => _SetupInterestsScreenState();
}

class _SetupInterestsScreenState extends State<SetupInterestsScreen> {
  final Set<String> _selectedInterests = <String>{};
  final _userService = UserService();
  bool _isLoading = false;

  final List<InterestItem> _interests = <InterestItem>[
    const InterestItem(name: 'Музыка', icon: Icons.music_note, color: Color(0xFF5E60CE)),
    const InterestItem(name: 'Спорт', icon: Icons.sports_soccer, color: Color(0xFF7B68EE)),
    const InterestItem(name: 'Кино', icon: Icons.movie, color: Color(0xFF9370DB)),
    const InterestItem(name: 'IT', icon: Icons.computer, color: Color(0xFF5E60CE)),
    const InterestItem(name: 'Искусство', icon: Icons.palette, color: Color(0xFF7B68EE)),
    const InterestItem(name: 'Книги', icon: Icons.book, color: Color(0xFF9370DB)),
    const InterestItem(name: 'Еда', icon: Icons.restaurant, color: Color(0xFF5E60CE)),
    const InterestItem(name: 'Путешествия', icon: Icons.flight, color: Color(0xFF7B68EE)),
    const InterestItem(name: 'Фотография', icon: Icons.camera_alt, color: Color(0xFF9370DB)),
    const InterestItem(name: 'Мода', icon: Icons.checkroom, color: Color(0xFF5E60CE)),
    const InterestItem(name: 'Танцы', icon: Icons.album, color: Color(0xFF7B68EE)),
    const InterestItem(name: 'Игры', icon: Icons.videogame_asset, color: Color(0xFF9370DB)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите минимум 3 интереса'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Отправляем интересы на backend
      await _userService.updateProfile(
        interests: _selectedInterests.toList(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const SetupLocationScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A4D6A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Прогресс
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E60CE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E60CE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Заголовок
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Выберите интересы',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A4D6A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Помогут найти события и людей по душе',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Счетчик
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _canContinue
                    ? const Color(0xFF5E60CE).withOpacity(0.1)
                    : const Color(0xFFE0E0E0).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    _canContinue ? Icons.check_circle : Icons.info_outline,
                    color: _canContinue
                        ? const Color(0xFF5E60CE)
                        : const Color(0xFF9E9E9E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Выбрано: ${_selectedInterests.length} из 3 минимум',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _canContinue
                          ? const Color(0xFF5E60CE)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Список интересов
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _interests.length,
                itemBuilder: (BuildContext context, int index) {
                  final InterestItem interest = _interests[index];
                  final bool isSelected =
                      _selectedInterests.contains(interest.name);

                  return GestureDetector(
                    onTap: () => _toggleInterest(interest.name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? interest.color.withOpacity(0.1)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? interest.color
                              : const Color(0xFFE0E0E0),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            interest.icon,
                            color: isSelected
                                ? interest.color
                                : const Color(0xFF9E9E9E),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            interest.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? interest.color
                                  : const Color(0xFF4A4D6A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Кнопка продолжить
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E60CE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Продолжить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InterestItem {
  const InterestItem({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}
