import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Александр Иванов');
  final _bioController = TextEditingController(
    text: 'Люблю спорт, музыку и путешествия. Ищу новые впечатления и интересные события!',
  );
  final _instagramController = TextEditingController(text: '@alex_ivanov');
  
  bool _isLoading = false;
  
  final List<String> _allInterests = <String>[
    'Спорт',
    'Музыка',
    'Искусство',
    'Еда',
    'Технологии',
    'Образование',
    'Развлечения',
    'Бизнес',
    'Путешествия',
    'Фотография',
    'Кино',
    'Книги',
    'Игры',
    'Йога',
    'Танцы',
    'Мода',
  ];
  
  final List<String> _selectedInterests = <String>[
    'Спорт',
    'Музыка',
    'Путешествия',
    'Технологии',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      
      // Симуляция сохранения
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль успешно обновлен!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
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
        title: const Text(
          'Редактировать профиль',
          style: TextStyle(
            color: Color(0xFF4A4D6A),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: <Widget>[
            // Фото профиля
            Center(
              child: Stack(
                children: <Widget>[
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF5E60CE),
                    child: const Text(
                      'АИ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E60CE),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
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
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Выбрать фото
                },
                child: const Text('Изменить фото'),
              ),
            ),
            const SizedBox(height: 32),
            
            // Имя
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Имя',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Введите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // О себе
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'О себе',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Расскажите о себе';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Instagram
            TextFormField(
              controller: _instagramController,
              decoration: InputDecoration(
                labelText: 'Instagram',
                prefixIcon: const Icon(Icons.camera_alt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Интересы
            const Text(
              'Ваши интересы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4D6A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Выберите минимум 3 интереса',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((String interest) {
                final bool isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (bool selected) => _toggleInterest(interest),
                  selectedColor: const Color(0xFF5E60CE).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF5E60CE),
                  backgroundColor: const Color(0xFFF5F5F5),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF5E60CE) : const Color(0xFF4A4D6A),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF5E60CE) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            
            // Настройки приватности
            const Text(
              'Приватность',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4D6A),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('Показывать в поиске'),
                    subtitle: const Text('Другие пользователи смогут найти вас'),
                    value: true,
                    activeThumbColor: const Color(0xFF5E60CE),
                    onChanged: (bool value) {
                      // TODO: Изменить настройки
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Показывать посещенные события'),
                    subtitle: const Text('В вашем профиле'),
                    value: true,
                    activeThumbColor: const Color(0xFF5E60CE),
                    onChanged: (bool value) {
                      // TODO: Изменить настройки
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Получать уведомления о матчах'),
                    subtitle: const Text('Когда появляется новое совпадение'),
                    value: true,
                    activeThumbColor: const Color(0xFF5E60CE),
                    onChanged: (bool value) {
                      // TODO: Изменить настройки
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Кнопка сохранения
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Сохранить изменения',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            
            // Кнопка выхода
            OutlinedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Выйти из аккаунта?'),
                      content: const Text('Вы уверены, что хотите выйти?'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Вызываем событие выхода из аккаунта
                            context.read<AuthBloc>().add(const AuthLogoutRequested());
                          },
                          child: const Text(
                            'Выйти',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
