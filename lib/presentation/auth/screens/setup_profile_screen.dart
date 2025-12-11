import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../data/services/user_service.dart';
import 'setup_interests_screen.dart';
import '../../widgets/common/custom_dropdown.dart';

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
  String? _selectedGender;
  File? _profileImage;
  bool _isLoading = false;

  final List<String> _genders = <String>['Мужской', 'Женский', 'Не указывать'];

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
        maxWidth: 512,  // Уменьшили для симулятора
        maxHeight: 512,
        imageQuality: 60,  // Сильнее сжимаем
      );

      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted && e.toString().contains('multiple_request')) {
        CustomNotification.error(context, 'Операция отменена. Попробуйте еще раз');
      }
      print('Image picker error: $e');
    }
  }

  Future<void> _handleNext() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        String? photoUrl;

        // Загружаем фото если выбрано
        if (_profileImage != null) {
          print('🔵 [SetupProfile] Загружаем фото...');
          try {
            photoUrl = await _userService.uploadProfilePhoto(_profileImage!);
            print('🟢 [SetupProfile] Фото загружено: $photoUrl');
          } catch (photoError) {
            print('🟡 [SetupProfile] Не удалось загрузить фото: $photoError');
            print('🟡 [SetupProfile] Продолжаем без фото (можно добавить позже)');
            // Не прерываем процесс, продолжаем без фото
          }
        } else {
          print('🟡 [SetupProfile] Фото не выбрано');
        }

        // Отправляем данные профиля на backend
        print('🔵 [SetupProfile] Отправляем профиль с photoUrl: $photoUrl');
        await _userService.updateProfile(
          photoUrl: photoUrl,
          age: int.tryParse(_ageController.text),
          gender: _selectedGender,
        );
        print('🟢 [SetupProfile] Профиль обновлён');

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const SetupInterestsScreen(),
            ),
          );
        }
      } catch (e) {
        print('🔴 [SetupProfile] Ошибка: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          CustomNotification.show(context, 'Ошибка: $e', isError: true);
        }
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
        actions: <Widget>[
          TextButton(
            onPressed: _handleSkip,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          color: const Color(0xFFE0E0E0),
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
                const SizedBox(height: 32),

                // Заголовок
                const Text(
                  'Расскажите о себе',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A4D6A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Это поможет найти интересных людей',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 40),

                // Фото профиля
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: <Widget>[
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF5E60CE).withOpacity(0.1),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color(0xFF5E60CE),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5E60CE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Добавить фото (опционально)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 40),

                // Возраст
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Возраст',
                    hintText: 'Введите ваш возраст',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF5E60CE),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return null; // Опционально
                    }
                    final int? age = int.tryParse(value);
                    if (age == null || age < 18 || age > 100) {
                      return 'Введите корректный возраст (18-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Пол
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
                ),
                const SizedBox(height: 40),

                // Кнопка продолжить
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E60CE),
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
                
                const SizedBox(height: 16),
                
                // Кнопка пропустить фото
                TextButton(
                  onPressed: _isLoading ? null : () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      setState(() => _isLoading = true);
                      
                      try {
                        // Отправляем только возраст и пол, без фото
                        await _userService.updateProfile(
                          age: int.tryParse(_ageController.text),
                          gender: _selectedGender,
                        );

                        if (mounted) {
                          setState(() => _isLoading = false);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => const SetupInterestsScreen(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          CustomNotification.show(
                            context,
                            'Ошибка при обновлении профиля: $e',
                            isError: true,
                          );
                        }
                      }
                    }
                  },
                  child: Text(
                    'Пропустить добавление фото',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
