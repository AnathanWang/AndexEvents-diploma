import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../core/services/logger_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'privacy_settings_screen.dart';
import '../widgets/photo_gallery_sheet.dart';
import '../../auth/widgets/auth_glass_card.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final GlobalKey _avatarPreviewKey = GlobalKey();
  final Map<String, GlobalKey> _photoPreviewKeys = <String, GlobalKey>{};

  Map<String, String> _socialLinks = {};

  File? _newProfileImage;
  File? _newCoverImage;
  final List<File> _newPhotos = [];
  List<String> _existingPhotos = [];
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  bool _showVisitedEvents = true;
  bool _showInMatches = true;
  bool _incognitoMode = false;
  bool _hideOnlineStatus = false;
  int? _minMatchAge;
  int? _maxMatchAge;

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
      _socialLinks =
          user.socialLinks?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {};
      _existingPhotos = List.from(user.photos);
      _showVisitedEvents = user.showVisitedEvents;
      _showInMatches = user.showInMatches;
      _incognitoMode = user.incognitoMode;
      _hideOnlineStatus = user.hideOnlineStatus;
      _minMatchAge = user.minAge;
      _maxMatchAge = user.maxAge;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF5F76FF)) : null,
      filled: true,
      fillColor: const Color(0xFFF5F8FF),
      labelStyle: const TextStyle(color: Color(0xFF5D668C)),
      hintStyle: const TextStyle(color: Color(0xFF97A0C4)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE3E9FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF637DFF), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDE5A77)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDE5A77), width: 1.6),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _newProfileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted && e.toString().contains('multiple_request')) {
        CustomNotification.show(
          context,
          'Операция отменена. Попробуйте еще раз',
          isError: true,
        );
      }
      LoggerService.error('Image picker error: $e');
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1200,
        imageQuality: 86,
      );

      if (image != null && mounted) {
        setState(() {
          _newCoverImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted && e.toString().contains('multiple_request')) {
        CustomNotification.show(
          context,
          'Операция отменена. Попробуйте еще раз',
          isError: true,
        );
      }
      LoggerService.error('Cover image picker error: $e');
    }
  }

  Future<void> _pickAdditionalPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty && mounted) {
        // Ограничиваем до 5 фото всего (существующие + новые)
        final totalAllowed = 5;
        final currentTotal = _existingPhotos.length + _newPhotos.length;
        final canAdd = totalAllowed - currentTotal;

        if (canAdd <= 0) {
          CustomNotification.error(context, 'Максимум 5 фотографий');
          return;
        }

        final imagesToAdd = images.take(canAdd).toList();
        setState(() {
          _newPhotos.addAll(imagesToAdd.map((e) => File(e.path)));
        });

        if (images.length > canAdd) {
          CustomNotification.error(
            context,
            'Добавлено $canAdd из ${images.length} фото (лимит 5)',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          'Ошибка выбора фото: $e',
          isError: true,
        );
      }
      LoggerService.error('Image picker error: $e');
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  GlobalKey _previewKeyFor(String path) {
    return _photoPreviewKeys.putIfAbsent(path, () => GlobalKey());
  }

  Rect? _rectForKey(GlobalKey key) {
    final keyContext = key.currentContext;
    if (keyContext == null) return null;
    final renderObject = keyContext.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  String? _currentAvatarPath(UserModel? user) {
    if (_newProfileImage != null) return _newProfileImage!.path;
    final photoUrl = user?.photoUrl?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) return photoUrl;
    return null;
  }

  List<String> _additionalPhotoPaths() {
    return <String>[
      ..._existingPhotos,
      ..._newPhotos.map((photo) => photo.path),
    ];
  }

  List<String> _galleryOrderedPhotos(UserModel? user) {
    final ordered = <String>[];
    final avatarPath = _currentAvatarPath(user);
    if (avatarPath != null && avatarPath.isNotEmpty) {
      ordered.add(avatarPath);
    }

    for (final path in _additionalPhotoPaths()) {
      if (!ordered.contains(path)) {
        ordered.add(path);
      }
    }

    return ordered;
  }

  Future<void> _openPhotoGallery({
    required UserModel? user,
    required Rect? sourceRect,
    int initialIndex = 0,
  }) async {
    final orderedPhotos = _galleryOrderedPhotos(user);
    if (orderedPhotos.isEmpty) return;

    final mainPhoto = _currentAvatarPath(user);
    final extraPhotos = List<String>.from(orderedPhotos);
    if (mainPhoto != null && extraPhotos.isNotEmpty && extraPhotos.first == mainPhoto) {
      extraPhotos.removeAt(0);
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoGallerySheet(
            photos: extraPhotos,
            mainPhotoUrl: mainPhoto,
            initialIndex: initialIndex,
            initialAvatarSize: sourceRect?.width ?? 120,
            sourceRect: sourceRect,
          );
        },
        transitionDuration: const Duration(milliseconds: 10),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  Widget _buildPhotoPreview(String path) {
    final isNetworkImage =
        path.startsWith('http://') || path.startsWith('https://');

    if (isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFFF3F4F8),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFF3F4F8),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _buildAdditionalPhotosSection(UserModel? user) {
    final photoPaths = _additionalPhotoPaths();
    final canAddMore = photoPaths.length < 5;
    final orderedPhotos = _galleryOrderedPhotos(user);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF7FAFF), Color(0xFFF1F7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Дополнительные фото',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF161823),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${photoPaths.length}/5',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5F76FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: photoPaths.length + (canAddMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == photoPaths.length) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickAdditionalPhotos,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Colors.white, Color(0xFFF4F8FF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFBFD3FF),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Color(0xFF5F76FF),
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Фото',
                            style: TextStyle(
                              color: Color(0xFF5F76FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final path = photoPaths[index];
              final previewKey = _previewKeyFor(path);
              final galleryIndex = orderedPhotos.indexOf(path);
              final isExisting = index < _existingPhotos.length;

              return GestureDetector(
                onTap: () => _openPhotoGallery(
                  user: user,
                  sourceRect: _rectForKey(previewKey),
                  initialIndex: galleryIndex < 0 ? 0 : galleryIndex,
                ),
                child: Container(
                  key: previewKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _buildPhotoPreview(path),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              if (isExisting) {
                                _removeExistingPhoto(index);
                              } else {
                                _removeNewPhoto(index - _existingPhotos.length);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedInterests.length < 3) {
        CustomNotification.error(context, 'Выберите минимум 3 интереса');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final userService = UserService();

        // Загружаем основное фото если выбрано
        String? newPhotoUrl;
        if (_newProfileImage != null) {
          newPhotoUrl = await userService.uploadProfilePhoto(_newProfileImage!);
        }

        // Загружаем дополнительные фото
        List<String> uploadedPhotoUrls = List.from(_existingPhotos);
        for (final photo in _newPhotos) {
          final url = await userService.uploadAdditionalPhoto(photo);
          uploadedPhotoUrls.add(url);
        }

        String? newCoverUrl;
        if (_newCoverImage != null) {
          newCoverUrl = await userService.uploadCoverPhoto(_newCoverImage!);
        }

        if (!mounted) return;

        // Обновляем профиль со всеми данными
        context.read<ProfileBloc>().add(
          ProfileUpdateRequested(
            displayName: _nameController.text.trim(),
            bio: _bioController.text.trim(),
            photoUrl: newPhotoUrl,
            coverImageUrl: newCoverUrl,
            photos: uploadedPhotoUrls,
            interests: _selectedInterests,
            socialLinks: _socialLinks.isNotEmpty ? _socialLinks : null,
            showVisitedEvents: _showVisitedEvents,
            showInMatches: _showInMatches,
            incognitoMode: _incognitoMode,
            hideOnlineStatus: _hideOnlineStatus,
            minAge: _minMatchAge,
            maxAge: _maxMatchAge,
            clearMinAge:
                _minMatchAge == null && _currentUser?.minAge != null,
            clearMaxAge:
                _maxMatchAge == null && _currentUser?.maxAge != null,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        CustomNotification.error(context, 'Ошибка загрузки фото: $e');
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
    } else if (platformLower.contains('vk') ||
        platformLower.contains('вконтакте')) {
      icon = Icons.group;
      color = const Color(0xFF0077FF);
    } else if (platformLower.contains('facebook')) {
      icon = Icons.facebook;
      color = const Color(0xFF1877F2);
    } else if (platformLower.contains('twitter') ||
        platformLower.contains('x')) {
      icon = Icons.alternate_email;
      color = Colors.black;
    } else {
      icon = Icons.link;
      color = const Color(0xFF75878A);
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
                if (nameController.text.isNotEmpty &&
                    urlController.text.isNotEmpty) {
                  setState(() {
                    _socialLinks[nameController.text.trim()] = urlController
                        .text
                        .trim();
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

  Future<void> _openPrivacySettings() async {
    final result = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute<Map<String, Object?>>(
        builder: (context) => PrivacySettingsScreen(
          showVisitedEvents: _showVisitedEvents,
          showInMatches: _showInMatches,
          incognitoMode: _incognitoMode,
          hideOnlineStatus: _hideOnlineStatus,
          minAge: _minMatchAge,
          maxAge: _maxMatchAge,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _showVisitedEvents =
          result['showVisitedEvents'] as bool? ?? _showVisitedEvents;
      _showInMatches =
          result['showInMatches'] as bool? ?? _showInMatches;
      _incognitoMode =
          result['incognitoMode'] as bool? ?? _incognitoMode;
      _hideOnlineStatus =
          result['hideOnlineStatus'] as bool? ?? _hideOnlineStatus;
      _minMatchAge = result['minAge'] as int?;
      _maxMatchAge = result['maxAge'] as int?;
    });
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
          // Если было реальное обновление - закрываем экран с success result
          else if (_isLoading) {
            setState(() => _isLoading = false);
            // Pop with result=true so the parent screen can show the notification
            Navigator.of(context).pop(true);
          } else {
            setState(() => _isLoading = false);
          }
        } else if (state is ProfileLoading || state is ProfileUpdating) {
          setState(() => _isLoading = true);
        } else if (state is ProfileError) {
          setState(() => _isLoading = false);
          CustomNotification.error(context, state.message);
        }
      },
      builder: (context, state) {
        final user = state is ProfileLoaded ? state.user : _currentUser;

        return AuthGlassScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF243252)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Редактировать профиль',
              style: TextStyle(
                color: Color(0xFF1F3552),
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            actions: <Widget>[
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF243252)),
                onSelected: (value) {
                  if (value == 'privacy') {
                    _openPrivacySettings();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'privacy',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.shield_outlined),
                        SizedBox(width: 12),
                        Text('Настройки приватности'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          child: _isLoading && user == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: <Widget>[
                      // Обложка профиля
                      AuthGlassCard(
                        padding: const EdgeInsets.all(0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: 140,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                if (_newCoverImage != null)
                                  Image.file(_newCoverImage!, fit: BoxFit.cover)
                                else if (user?.coverImageUrl != null &&
                                    user!.coverImageUrl!.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: user.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: <Color>[
                                            Color(0xFF5F76FF),
                                            Color(0xFF62A9FF),
                                            Color(0xFF63C9B5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0xFF5F76FF),
                                          Color(0xFF62A9FF),
                                          Color(0xFF63C9B5),
                                        ],
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Material(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: _pickCoverImage,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.wallpaper_outlined,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Фон',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
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
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Фото профиля
                      Center(
                        child: GestureDetector(
                          onTap: () => _openPhotoGallery(
                            user: user,
                            sourceRect: _rectForKey(_avatarPreviewKey),
                          ),
                          child: Stack(
                            children: <Widget>[
                              _newProfileImage != null
                                  ? Container(
                                      key: _avatarPreviewKey,
                                      width: 120,
                                      height: 120,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.file(
                                          _newProfileImage!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : (user?.photoUrl != null &&
                                        user!.photoUrl!.isNotEmpty)
                                  ? Container(
                                      key: _avatarPreviewKey,
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF75878A),
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: user.photoUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) {
                                            LoggerService.error(
                                              '🔴 [EditProfile] Не удалось загрузить аватар: $error',
                                            );
                                            return CircleAvatar(
                                              radius: 60,
                                              backgroundColor: const Color(
                                                0xFF75878A,
                                              ),
                                              child: Text(
                                                user.displayName?.isNotEmpty ==
                                                        true
                                                    ? user.displayName![0]
                                                          .toUpperCase()
                                                    : user.email[0]
                                                          .toUpperCase(),
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
                                      key: _avatarPreviewKey,
                                      radius: 60,
                                      backgroundColor: const Color(0xFF75878A),
                                      child: Text(
                                        user?.displayName?.isNotEmpty == true
                                            ? user!.displayName![0]
                                                  .toUpperCase()
                                            : user?.email[0].toUpperCase() ??
                                                  'U',
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
                                    color: const Color(0xFF75878A),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
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
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Аватар'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5F76FF),
                                side: const BorderSide(
                                  color: Color(0xFFBFD3FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickAdditionalPhotos,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              label: const Text('Фото'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5F76FF),
                                side: const BorderSide(
                                  color: Color(0xFFBFD3FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickCoverImage,
                              icon: const Icon(Icons.wallpaper_outlined, size: 18),
                              label: const Text('Фон'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5F76FF),
                                side: const BorderSide(
                                  color: Color(0xFFBFD3FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildAdditionalPhotosSection(user),
                      const SizedBox(height: 32),

                      // Имя
                      TextFormField(
                        controller: _nameController,
                        decoration: _buildInputDecoration(
                          label: 'Имя',
                          icon: Icons.person_outline,
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
                        decoration: _buildInputDecoration(
                          label: 'О себе',
                          hint: 'Пара строк о вас, интересах и том, что вы ищете',
                          alignLabelWithHint: true,
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
                              color: Color(0xFF161823),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddSocialLinkDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5F76FF),
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
                            color: Color(0xFF66739B),
                          ),
                        )
                      else
                        ..._socialLinks.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: const Color(0xFFF7FAFF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFE2E9FB)),
                            ),
                            child: ListTile(
                              leading: _getSocialIcon(entry.key),
                              title: Text(entry.key),
                              subtitle: Text(
                                entry.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _socialLinks.remove(entry.key);
                                  });
                                },
                              ),
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
                          color: Color(0xFF161823),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Выберите минимум 3 интереса',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF66739B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allInterests.map((String interest) {
                          final bool isSelected = _selectedInterests.contains(
                            interest,
                          );
                          return FilterChip(
                            label: Text(interest),
                            selected: isSelected,
                            onSelected: (bool selected) =>
                                _toggleInterest(interest),
                            selectedColor: const Color(
                              0xFF5F76FF,
                            ).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFF5F76FF),
                            backgroundColor: const Color(0xFFF5F8FF),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF5F76FF)
                                  : const Color(0xFF243252),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF5F76FF)
                                    : const Color(0xFFE2E9FB),
                                width: 1.4,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Кнопка сохранения
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
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
                                'Сохранить изменения',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                                content: const Text(
                                  'Вы уверены, что хотите выйти?',
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      // Вызываем событие выхода из аккаунта
                                      context.read<AuthBloc>().add(
                                        const AuthLogoutRequested(),
                                      );
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
