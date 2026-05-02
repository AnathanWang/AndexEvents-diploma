import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_service.dart';
import '../../home/home_shell.dart';
import '../../widgets/common/custom_notification.dart';

/// Экран 3: Настройка геолокации
/// Запрос разрешения на доступ к местоположению
class SetupLocationScreen extends StatefulWidget {
  const SetupLocationScreen({super.key});

  @override
  State<SetupLocationScreen> createState() => _SetupLocationScreenState();
}

class _SetupLocationScreenState extends State<SetupLocationScreen> {
  final UserService _userService = UserService();
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
    if (!mounted) return;
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
        final Position position = await Geolocator.getCurrentPosition();

        setState(() {
          _permissionStatus = permission;
          _currentPosition = position;
          _isLoading = false;
        });

        await _completeOnboarding();
      } else {
        setState(() {
          _permissionStatus = permission;
          _isLoading = false;
        });

        if (mounted) {
          CustomNotification.error(
            context,
            'Разрешите доступ к местоположению для продолжения',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        CustomNotification.error(context, 'Ошибка: $e');
      }
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      if (_currentPosition == null) {
        try {
          LoggerService.debug('DEBUG: Получаем текущую позицию...');
          final Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          _currentPosition = position;
          LoggerService.debug(
            'DEBUG: Позиция получена: ${position.latitude}, ${position.longitude}',
          );
        } catch (e) {
          LoggerService.debug('DEBUG: Не удалось получить позицию: $e');
        }
      }

      if (_currentPosition != null) {
        LoggerService.debug('DEBUG: Отправляем координаты на backend...');
        await _userService.updateLocation(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
        LoggerService.debug('DEBUG: Координаты отправлены успешно');
      } else {
        LoggerService.debug('DEBUG: Координаты не получены, пропускаем отправку');
      }

      LoggerService.debug('DEBUG: Устанавливаем isOnboardingCompleted = true');
      await _userService.updateProfile(
        isOnboardingCompleted: true,
      );
      await AuthService().cacheOnboardingStatus(true);

      if (!mounted) return;

      setState(() => _isLoading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const HomeShell(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      LoggerService.error('DEBUG: Ошибка в _completeOnboarding: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomNotification.error(context, 'Ошибка завершения настройки: $e');
    }
  }

  Future<void> _skipLocation() async {
    setState(() => _isLoading = true);

    try {
      await _userService.updateProfile(
        isOnboardingCompleted: true,
      );
      await AuthService().cacheOnboardingStatus(true);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const HomeShell(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomNotification.error(context, 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPermission =
        _permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF273043)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _isLoading ? null : _skipLocation,
            child: const Text(
              'Пропустить',
              style: TextStyle(
                color: Color(0xFF4D5A89),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
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
              top: -100,
              right: -65,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6D86FF).withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -90,
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF63C9B6).withValues(alpha: 0.14),
                ),
              ),
            ),
            SafeArea(
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
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      hasPermission ? 'Почти готово' : 'Включите геолокацию',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2441),
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasPermission
                          ? 'Мы нашли ваше местоположение. Осталось завершить настройку и можно переходить к событиям.'
                          : 'Локация помогает показывать события, знакомства и подсказки рядом с вами.',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5D668C),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFDCE4FF)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF5762A8).withValues(alpha: 0.09),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 126,
                            height: 126,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: hasPermission
                                    ? const <Color>[
                                        Color(0xFF63C9B5),
                                        Color(0xFF5F76FF),
                                      ]
                                    : const <Color>[
                                        Color(0xFF5F76FF),
                                        Color(0xFF62A9FF),
                                      ],
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF5F76FF).withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEFF3FF),
                              ),
                              child: Icon(
                                hasPermission
                                    ? Icons.check_circle_rounded
                                    : Icons.location_on_rounded,
                                size: 62,
                                color: hasPermission
                                    ? const Color(0xFF54BFAE)
                                    : const Color(0xFF637DFF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasPermission
                                ? 'Геопозиция подключена'
                                : 'Доступ к местоположению',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF243252),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasPermission
                                ? 'Теперь вы сможете быстрее находить события и людей поблизости.'
                                : 'Разрешение нужно, чтобы рекомендации были ближе к вашему городу и району.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF66739B),
                              height: 1.4,
                            ),
                          ),
                          if (_currentPosition != null) ...<Widget>[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFF3F7FF),
                                    Color(0xFFEAF8F3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFD8E9FF),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: <Color>[
                                          Color(0xFF63C9B5),
                                          Color(0xFF6AA8FF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.explore_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Координаты: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4B5877),
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ..._buildFeatures(hasPermission),
                          const SizedBox(height: 22),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: hasPermission
                                    ? const <Color>[
                                        Color(0xFF63C9B5),
                                        Color(0xFF5F76FF),
                                      ]
                                    : const <Color>[
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
                              onPressed: _isLoading
                                  ? null
                                  : (hasPermission
                                        ? _completeOnboarding
                                        : _requestPermission),
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
                                  : Text(
                                      hasPermission
                                          ? 'Завершить настройку'
                                          : 'Разрешить доступ',
                                      style: const TextStyle(
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
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatures(bool hasPermission) {
    final List<_LocationFeature> features = hasPermission
        ? const <_LocationFeature>[
            _LocationFeature(
              icon: Icons.event_available_rounded,
              title: 'Локальные события',
              description: 'Подборки будут учитывать то, что происходит рядом.',
            ),
            _LocationFeature(
              icon: Icons.people_alt_rounded,
              title: 'Ближайшие знакомства',
              description:
                  'Матчи и рекомендации людей станут заметно релевантнее.',
            ),
          ]
        : const <_LocationFeature>[
            _LocationFeature(
              icon: Icons.event_rounded,
              title: 'События рядом',
              description: 'Находите мероприятия в вашем районе и городе.',
            ),
            _LocationFeature(
              icon: Icons.people_rounded,
              title: 'Знакомства поблизости',
              description: 'Встречайте людей, с которыми реально пересечься.',
            ),
            _LocationFeature(
              icon: Icons.notifications_active_rounded,
              title: 'Актуальные подсказки',
              description: 'Быстрее узнавайте о новых активностях рядом.',
            ),
          ];

    return <Widget>[
      for (int i = 0; i < features.length; i++) ...<Widget>[
        _FeatureCard(feature: features[i]),
        if (i != features.length - 1) const SizedBox(height: 12),
      ],
    ];
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _LocationFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E9FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              feature.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.38,
                    color: Color(0xFF66739B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationFeature {
  const _LocationFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
