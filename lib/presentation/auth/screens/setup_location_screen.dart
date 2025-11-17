import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../home/home_shell.dart';

/// Экран 3: Настройка геолокации
/// Запрос разрешения на доступ к местоположению
class SetupLocationScreen extends StatefulWidget {
  const SetupLocationScreen({super.key});

  @override
  State<SetupLocationScreen> createState() => _SetupLocationScreenState();
}

class _SetupLocationScreenState extends State<SetupLocationScreen> {
  bool _isLoading = false;
  LocationPermission? _permissionStatus;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    setState(() {
      _permissionStatus = permission;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);

    try {
      final LocationPermission permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Получаем текущую позицию
        final Position position = await Geolocator.getCurrentPosition();
        
        setState(() {
          _permissionStatus = permission;
          _currentPosition = position;
          _isLoading = false;
        });

        // TODO: Отправить координаты на backend
        await _completeOnboarding();
      } else {
        setState(() {
          _permissionStatus = permission;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешите доступ к местоположению для продолжения'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    // TODO: Вызвать API для завершения онбординга
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      // Переход на главный экран
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const HomeShell(),
        ),
        (Route<dynamic> route) => false, // Удаляем все предыдущие экраны
      );
    }
  }

  void _skipLocation() {
    // Пропустить настройку локации
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const HomeShell(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPermission = _permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A4D6A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _skipLocation,
            child: const Text(
              'Пропустить',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: <Widget>[
              // Прогресс
              Row(
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
                        color: const Color(0xFF5E60CE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Иконка
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF5E60CE).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasPermission ? Icons.check_circle : Icons.location_on,
                  size: 80,
                  color: const Color(0xFF5E60CE),
                ),
              ),
              const SizedBox(height: 48),

              // Заголовок
              Text(
                hasPermission ? 'Отлично!' : 'Разрешите доступ к локации',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A4D6A),
                ),
              ),
              const SizedBox(height: 16),

              // Описание
              Text(
                hasPermission
                    ? 'Теперь вы можете найти события и людей рядом с вами'
                    : 'Нужно для поиска событий и знакомств поблизости',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9E9E9E),
                  height: 1.5,
                ),
              ),

              if (_currentPosition != null) ...<Widget>[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E60CE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.location_city,
                        color: Color(0xFF5E60CE),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Координаты: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A4D6A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Преимущества
              if (!hasPermission) ...<Widget>[
                _buildFeature(
                  icon: Icons.event,
                  title: 'События рядом',
                  description: 'Находите мероприятия в вашем районе',
                ),
                const SizedBox(height: 16),
                _buildFeature(
                  icon: Icons.people,
                  title: 'Знакомства',
                  description: 'Встречайте людей поблизости',
                ),
                const SizedBox(height: 16),
                _buildFeature(
                  icon: Icons.notifications,
                  title: 'Уведомления',
                  description: 'Узнавайте о новых событиях первыми',
                ),
                const SizedBox(height: 32),
              ],

              // Кнопка
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (hasPermission ? _completeOnboarding : _requestPermission),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        hasPermission ? 'Завершить настройку' : 'Разрешить доступ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF5E60CE).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5E60CE),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4D6A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
