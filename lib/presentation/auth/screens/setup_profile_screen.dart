import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import '../../../data/services/user_service.dart';
import '../../../data/services/auth_service.dart';
import 'setup_interests_screen.dart';
import '../../widgets/common/custom_dropdown.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'login_screen.dart';
import '../widgets/auth_glass_card.dart';
import '../widgets/auth_glass_scaffold.dart';
import '../widgets/auth_input_decoration.dart';

/// Экран 1: Настройка базового профиля
/// Фото, возраст, пол
class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _userService = UserService();
  final _authService = AuthService();
  String? _selectedGender;
  File? _profileImage;
  bool _isLoading = false;

  final List<String> _genders = <String>['Мужской', 'Женский', 'Не указывать'];

  String? _normalizeGender(String? raw) {
    switch (raw) {
      case 'Мужской':
        return 'male';
      case 'Женский':
        return 'female';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Уменьшили для симулятора
        maxHeight: 512,
        imageQuality: 60, // Сильнее сжимаем
      );

      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted && e.toString().contains('multiple_request')) {
        CustomNotification.error(
          context,
          'Операция отменена. Попробуйте еще раз',
        );
      }
    }
  }

  Future<void> _handleNext() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        await _authService.ensureUserInBackend();

        String? photoUrl;

        if (_profileImage != null) {
          photoUrl = await _userService.uploadProfilePhoto(_profileImage!).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException('Загрузка фото заняла слишком много времени');
            },
          );
        }

        await _userService.updateProfile(
          photoUrl: photoUrl,
          age: int.tryParse(_ageController.text),
          gender: _normalizeGender(_selectedGender),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Обновление профиля заняло слишком много времени');
          },
        );

        if (!mounted) return;

        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const SetupInterestsScreen(),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        CustomNotification.show(context, 'Ошибка: $e', isError: true);
      }
    }
  }

  void _handleSkip() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SetupInterestsScreen(),
      ),
    );
  }

  Future<bool> _handleBackPress() async {
    // Показываем диалог подтверждения выхода
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы уверены что хотите выйти? Прогресс настройки профиля не будет сохранен.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Выполняем logout
      if (mounted) {
        context.read<AuthBloc>().add(const AuthLogoutRequested());
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _continueWithoutPhoto() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.ensureUserInBackend();

      await _userService.updateProfile(
        age: int.tryParse(_ageController.text),
        gender: _normalizeGender(_selectedGender),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const SetupInterestsScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomNotification.show(
        context,
        'Ошибка при обновлении профиля: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: AuthGlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF273043)),
            onPressed: _handleBackPress,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _isLoading ? null : _handleSkip,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: _formKey,
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
                                color: const Color(0xFFDCE4FF),
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
                        'Расскажите о себе',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2441),
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Соберем базовый профиль, чтобы рекомендовать людей и события точнее.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF5D668C),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AuthGlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        child: Column(
                          children: <Widget>[
                            GestureDetector(
                              onTap: _isLoading ? null : _pickImage,
                              child: Stack(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0xFF6578FF),
                                          Color(0xFF62C9B5),
                                        ],
                                      ),
                                    ),
                                    child: Container(
                                      width: 118,
                                      height: 118,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFEFF3FF),
                                        image: _profileImage != null
                                            ? DecorationImage(
                                                image: FileImage(_profileImage!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _profileImage == null
                                          ? const Icon(
                                              Icons.person_rounded,
                                              size: 58,
                                              color: Color(0xFF637DFF),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF637DFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Добавить фото (опционально)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF67739A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: authInputDecoration(
                                label: 'Возраст',
                                hint: 'Введите ваш возраст',
                                icon: Icons.cake_outlined,
                              ),
                              validator: (String? value) {
                                if (value == null || value.isEmpty) {
                                  return null;
                                }
                                final int? age = int.tryParse(value);
                                if (age == null || age < 18 || age > 100) {
                                  return 'Введите корректный возраст (18-100)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            CustomDropdown<String>(
                              label: 'Пол',
                              value: _selectedGender,
                              prefixIcon: Icons.wc_outlined,
                              items: _genders.map((String gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                              useBottomSheet: true,
                              showBottomSheetCount: false,
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5F76FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
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
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _isLoading ? null : _continueWithoutPhoto,
                              child: const Text(
                                'Продолжить без фото',
                                style: TextStyle(
                                  color: Color(0xFF606B94),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
        ),
      ),
    ); // PopScope
  }
}
