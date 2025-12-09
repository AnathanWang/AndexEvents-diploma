import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../../../data/models/user_model.dart';
import '../../../core/config/app_config.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  
  Map<String, String> _socialLinks = {};
  
  File? _newProfileImage;
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  
  final List<String> _allInterests = <String>[
    'Спорт',
    'Музыка',
    'Искусство',
    'Еда',
    'Технологии',
    'IT',
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
  
  List<String> _selectedInterests = <String>[];

  @override
  void initState() {
    super.initState();
    // Загружаем профиль при открытии экрана
    context.read<ProfileBloc>().add(const ProfileLoadRequested());
  }

  void _initializeUserData(UserModel user) {
    if (_currentUser?.id != user.id) {
      _currentUser = user;
      _nameController.text = user.displayName ?? '';
      _bioController.text = user.bio ?? '';
      _selectedInterests = List.from(user.interests);
      _socialLinks = user.socialLinks?.map((key, value) => MapEntry(key, value.toString())) ?? {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedInterests.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите минимум 3 интереса'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Сначала загружаем фото если выбрано
      if (_newProfileImage != null) {
        context.read<ProfileBloc>().add(
          ProfilePhotoUpdateRequested(_newProfileImage!.path),
        );
      }

      // Затем обновляем остальные данные
      context.read<ProfileBloc>().add(
        ProfileUpdateRequested(
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          interests: _selectedInterests,
          socialLinks: _socialLinks.isNotEmpty ? _socialLinks : null,
        ),
      );
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

  Widget _getSocialIcon(String platform) {
    final platformLower = platform.toLowerCase();
    IconData icon;
    Color color;

    if (platformLower.contains('instagram')) {
      icon = Icons.camera_alt;
      color = const Color(0xFFE4405F);
    } else if (platformLower.contains('telegram')) {
      icon = Icons.send;
      color = const Color(0xFF0088cc);
    } else if (platformLower.contains('vk') || platformLower.contains('вконтакте')) {
      icon = Icons.group;
      color = const Color(0xFF0077FF);
    } else if (platformLower.contains('facebook')) {
      icon = Icons.facebook;
      color = const Color(0xFF1877F2);
    } else if (platformLower.contains('twitter') || platformLower.contains('x')) {
      icon = Icons.alternate_email;
      color = Colors.black;
    } else {
      icon = Icons.link;
      color = const Color(0xFF5E60CE);
    }

    return Icon(icon, color: color);
  }

  void _showAddSocialLinkDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Добавить социальную сеть'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Название',
                  hintText: 'Instagram, Telegram, VK...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'Ссылка или username',
                  hintText: '@username или полная ссылка',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                  setState(() {
                    _socialLinks[nameController.text.trim()] = urlController.text.trim();
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          _initializeUserData(state.user);
          
          // Если это первая загрузка - просто инициализируем данные
          if (_isInitialLoad) {
            setState(() {
              _isLoading = false;
              _isInitialLoad = false;
            });
          } 
          // Если было реальное обновление - закрываем экран и показываем сообщение
          else if (_isLoading) {
            setState(() => _isLoading = false);
            Navigator.of(context).pop();
            // Показываем snackbar после закрытия
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Профиль успешно обновлен!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            setState(() => _isLoading = false);
          }
        } else if (state is ProfileLoading || state is ProfileUpdating) {
          setState(() => _isLoading = true);
        } else if (state is ProfileError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final user = state is ProfileLoaded ? state.user : _currentUser;

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
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: <Widget>[
            // Фото профиля
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: <Widget>[
                    _newProfileImage != null
                        ? CircleAvatar(
                            radius: 60,
                            backgroundImage: FileImage(_newProfileImage!),
                          )
                        : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                            ? Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF5E60CE),
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user.photoUrl!,
                                    fit: BoxFit.cover,
                                    httpHeaders: {
                                      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                                    },
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      print('🔴 [EditProfile] Не удалось загрузить аватар: $error');
                                      return CircleAvatar(
                                        radius: 60,
                                        backgroundColor: const Color(0xFF5E60CE),
                                        child: Text(
                                          user.displayName?.isNotEmpty == true
                                              ? user.displayName![0].toUpperCase()
                                              : user.email[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFF5E60CE),
                                child: Text(
                                  user?.displayName?.isNotEmpty == true
                                      ? user!.displayName![0].toUpperCase()
                                      : user?.email[0].toUpperCase() ?? 'U',
                                  style: const TextStyle(
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
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickImage,
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
            const SizedBox(height: 32),
            
            // Социальные сети
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Социальные сети',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4D6A),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddSocialLinkDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5E60CE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_socialLinks.isEmpty)
              const Text(
                'Добавьте ссылки на свои социальные сети',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9E9E9E),
                ),
              )
            else
              ..._socialLinks.entries.map((entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: _getSocialIcon(entry.key),
                  title: Text(entry.key),
                  subtitle: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _socialLinks.remove(entry.key);
                      });
                    },
                  ),
                ),
              )),
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
      },
    );
  }
}
