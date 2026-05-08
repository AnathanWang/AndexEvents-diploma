import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/custom_notification.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_sanction_model.dart';
import '../../../data/models/event_draft_model.dart';
import '../../../data/services/event_draft_service.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import 'map_location_picker.dart';
import 'create_event/create_event_widgets.dart';
import 'create_event/create_event_drafts_sheet.dart';
import 'create_event/create_event_sections.dart';
import 'create_event/create_event_photos_section.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final UserService _userService = UserService();
  final EventDraftService _draftService = EventDraftService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _customCategoryController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasEndDateTime = false;
  DateTime _selectedEndDate = DateTime.now();
  TimeOfDay _selectedEndTime = TimeOfDay.now();
  final List<String> _selectedCategories = <String>['Спорт'];
  bool _isOnline = false;
  bool _isFree = true;
  bool _isPhotoUploading = false;
  bool _isLoading = false;
  
  final List<String> _uploadedPhotoUrls = <String>[];
  int _pendingPhotoUploads = 0;
  double? _latitude;
  double? _longitude;
  String? _activeDraftId;

  static const int _maxEventPhotos = 5;
  static const double _pageHorizontalPadding = 16;

  final List<String> _categories = <String>[
    'Спорт',
    'Музыка',
    'Искусство',
    'Еда',
    'Технологии',
    'Образование',
    'Развлечения',
    'Бизнес',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardCreateEventAccess();
      _maybeOfferRestoreDraft();
    });
  }

  bool _isCreateSanction(UserSanctionModel sanction) {
    final type = sanction.type.trim().toUpperCase();
    return sanction.isActive &&
        (type == 'EVENT_CREATE_BAN' || type == 'FULL_BAN');
  }

  Future<void> _guardCreateEventAccess() async {
    try {
      final sanctions = await _userService.getMySanctions();
      final block = sanctions.where(_isCreateSanction).toList();
      if (!mounted || block.isEmpty) return;

      final reason = block.first.reason.trim();
      final message =
          reason.isNotEmpty
              ? 'Создание событий ограничено: $reason'
              : 'Создание событий временно ограничено санкцией';

      CustomNotification.show(context, message, isError: true);
      Navigator.of(context).maybePop();
    } catch (_) {
      // If sanctions endpoint is temporarily unavailable, do not block UI here.
    }
  }

  Future<void> _openDraftsSheet() async {
    final drafts = await _draftService.listDrafts();
    if (!mounted) return;
    if (drafts.isEmpty) {
      CustomNotification.show(context, 'Черновиков пока нет');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return CreateEventDraftsSheet(
          drafts: drafts,
          onOpen: (draft) {
            Navigator.pop(context);
            _applyDraft(draft);
          },
          onRename: (draft) async {
            final controller = TextEditingController(text: draft.name);
            final newName = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Название черновика'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Например: “Вечер пятницы”',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      controller.text.trim(),
                    ),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            );
            if (newName == null || newName.trim().isEmpty) return;
            await _draftService.renameDraft(draft.id, newName.trim());
            if (context.mounted) Navigator.pop(context);
            if (mounted) _openDraftsSheet();
          },
          onDelete: (draft) async {
            await _draftService.deleteDraft(draft.id);
            if (context.mounted) Navigator.pop(context);
            if (mounted) _openDraftsSheet();
          },
        );
      },
    );
  }

  Future<void> _maybeOfferRestoreDraft() async {
    final drafts = await _draftService.listDrafts();
    if (!mounted || drafts.isEmpty) return;
    await _openDraftsSheet();
  }

  EventDraftModel _collectDraft({required String id, required String name}) {
    return EventDraftModel(
      id: id,
      name: name,
      title: _titleController.text,
      description: _descriptionController.text,
      locationText: _locationController.text,
      latitude: _latitude,
      longitude: _longitude,
      isOnline: _isOnline,
      isFree: _isFree,
      priceText: _priceController.text,
      selectedDate: _selectedDate,
      selectedTime: _selectedTime,
      hasEndDateTime: _hasEndDateTime,
      selectedEndDate: _selectedEndDate,
      selectedEndTime: _selectedEndTime,
      selectedCategories: List<String>.from(_selectedCategories),
      customCategory: _customCategoryController.text,
      uploadedPhotoUrls: List<String>.from(_uploadedPhotoUrls),
      savedAt: DateTime.now(),
    );
  }

  void _applyDraft(EventDraftModel draft) {
    setState(() {
      _activeDraftId = draft.id;
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
      _locationController.text = draft.locationText;
      _latitude = draft.latitude;
      _longitude = draft.longitude;
      _isOnline = draft.isOnline;
      _isFree = draft.isFree;
      _priceController.text = draft.priceText;
      _selectedDate = draft.selectedDate;
      _selectedTime = draft.selectedTime;
      _hasEndDateTime = draft.hasEndDateTime;
      _selectedEndDate = draft.selectedEndDate;
      _selectedEndTime = draft.selectedEndTime;

      _selectedCategories
        ..clear()
        ..addAll(draft.selectedCategories.isEmpty ? <String>['Спорт'] : draft.selectedCategories);
      _customCategoryController.text = draft.customCategory;

      _uploadedPhotoUrls
        ..clear()
        ..addAll(draft.uploadedPhotoUrls);
    });

    CustomNotification.show(context, 'Черновик восстановлен');
  }

  Future<void> _saveDraft() async {
    if (_pendingPhotoUploads > 0) {
      CustomNotification.show(
        context,
        'Идёт загрузка фото — часть может не сохраниться в черновик',
        isError: true,
      );
    }

    try {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Сохранить черновик'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Название (например: “Сбор на спорт”)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );

      if (name == null || name.trim().isEmpty) return;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await _draftService.upsertDraft(_collectDraft(id: id, name: name.trim()));
      if (!mounted) return;
      CustomNotification.show(context, 'Черновик сохранён');
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        'Не удалось сохранить черновик: $e',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.dark,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.dark,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate,
      firstDate: _selectedDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.dark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.dark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedEndTime) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );

      if (images.isNotEmpty && mounted) {
        final currentTotal = _uploadedPhotoUrls.length + _pendingPhotoUploads;
        if (currentTotal >= _maxEventPhotos) {
          CustomNotification.show(
            context,
            'Можно добавить максимум $_maxEventPhotos фото',
            isError: true,
          );
          return;
        }

        final canAdd = _maxEventPhotos - currentTotal;
        final imagesToAdd = images.take(canAdd).toList();

        setState(() {
          _pendingPhotoUploads += imagesToAdd.length;
          _isPhotoUploading = _pendingPhotoUploads > 0;
        });

        for (final image in imagesToAdd) {
          context.read<EventBloc>().add(EventPhotoUploadRequested(image.path));
        }

        if (images.length > canAdd) {
          CustomNotification.show(
            context,
            'Добавлено $canAdd из ${images.length} фото (лимит $_maxEventPhotos)',
          );
        }
      }
    } catch (e) {
      // Пользователь отменил выбор или произошла другая ошибка
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

  void _removeUploadedPhoto(int index) {
    setState(() {
      _uploadedPhotoUrls.removeAt(index);
    });
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _locationController.text.isEmpty ? null : _locationController.text,
        ),
      ),
    );

    if (result != null &&
        result['latitude'] != null &&
        result['longitude'] != null &&
        (result['address'] ?? '').toString().trim().isNotEmpty) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _locationController.text = result['address'].toString().trim();
      });
    }
  }

  Future<void> _handleCreateEvent() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Проверяем координаты для оффлайн события
      if (!_isOnline && (_latitude == null || _longitude == null)) {
        CustomNotification.show(
          context,
          'Выберите место на карте',
          isError: true,
        );
        return;
      }
      
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      DateTime? endDateTime;
      if (_hasEndDateTime) {
        endDateTime = DateTime(
          _selectedEndDate.year,
          _selectedEndDate.month,
          _selectedEndDate.day,
          _selectedEndTime.hour,
          _selectedEndTime.minute,
        );
        if (!endDateTime.isAfter(dateTime)) {
          CustomNotification.show(
            context,
            'Дата окончания должна быть позже начала события',
            isError: true,
          );
          return;
        }
      }
      
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final effectivePrice = _isFree ? 0.0 : price;
      
      // Для онлайн событий используем координаты по умолчанию (Москва)
      final lat = _isOnline ? 55.7558 : _latitude!;
      final lng = _isOnline ? 37.6173 : _longitude!;
      final location = _isOnline ? 'Онлайн' : _locationController.text;
      
      final categoryParts = <String>[
        ..._selectedCategories.map((e) => e.trim()).where((e) => e.isNotEmpty),
        if (_customCategoryController.text.trim().isNotEmpty)
          _customCategoryController.text.trim(),
      ];
      final category = categoryParts.isEmpty ? 'Спорт' : categoryParts.join(', ');

      context.read<EventBloc>().add(
        EventCreateRequested(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: category,
          location: location,
          latitude: lat,
          longitude: lng,
          dateTime: dateTime,
          endDateTime: endDateTime,
          price: effectivePrice,
          imageUrl: _uploadedPhotoUrls.isEmpty ? null : _uploadedPhotoUrls.first,
          imageUrls: _uploadedPhotoUrls.isEmpty ? null : _uploadedPhotoUrls,
          isOnline: _isOnline,
        ),
      );
    }
  }

  BoxDecoration _glassCardDecoration({
    double radius = 24,
    double alpha = 0.66,
    double borderAlpha = 0.16,
  }) {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.primary.withValues(alpha: borderAlpha)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.dark.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  InputDecoration _softInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: TextStyle(
        color: AppColors.dark.withValues(alpha: 0.62),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: AppColors.dark.withValues(alpha: 0.46),
        fontSize: 13,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.primary.withValues(alpha: 0.88)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF4F8FF).withValues(alpha: 0.98),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.92)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark.withValues(alpha: 0.86),
                  height: 1.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dark.withValues(alpha: 0.58),
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EventBloc, EventState>(
      listener: (context, state) {
        if (state is EventPhotoUploading) {
          setState(() => _isPhotoUploading = true);
        } else if (state is EventPhotoUploaded) {
          setState(() {
            final url = state.photoUrl.trim();
            if (url.isNotEmpty && !_uploadedPhotoUrls.contains(url)) {
              _uploadedPhotoUrls.add(url);
            }
            if (_pendingPhotoUploads > 0) {
              _pendingPhotoUploads -= 1;
            }
            _isPhotoUploading = _pendingPhotoUploads > 0;
          });
          if (_pendingPhotoUploads == 0) {
            CustomNotification.show(
              context,
              'Загружено ${_uploadedPhotoUrls.length} фото',
            );
          }
        } else if (state is EventCreating) {
          setState(() => _isLoading = true);
        } else if (state is EventCreated) {
          setState(() => _isLoading = false);
          final usedDraftId = _activeDraftId;
          if (usedDraftId != null && usedDraftId.trim().isNotEmpty) {
            _draftService.deleteDraft(usedDraftId);
            _activeDraftId = null;
          }
          Navigator.of(context).pop(true);
          CustomNotification.show(context, 'Событие успешно создано!');
        } else if (state is EventError) {
          setState(() {
            _isLoading = false;
            if (_pendingPhotoUploads > 0) {
              _pendingPhotoUploads -= 1;
            }
            _isPhotoUploading = _pendingPhotoUploads > 0;
          });
          CustomNotification.show(context, state.message, isError: true);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: AppColors.surface.withValues(alpha: 0.88),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: AppColors.dark.withValues(alpha: 0.78),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Создать событие',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Открыть черновики',
              onPressed: _isLoading ? null : _openDraftsSheet,
              icon: Icon(
                Icons.folder_open_rounded,
                color: AppColors.dark.withValues(alpha: 0.78),
              ),
            ),
            IconButton(
              tooltip: 'Сохранить черновик',
              onPressed: _isLoading ? null : _saveDraft,
              icon: Icon(
                Icons.save_rounded,
                color: AppColors.dark.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.surface.withValues(alpha: 0.94),
              AppColors.accent.withValues(alpha: 0.74),
              AppColors.surface.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              left: -120,
              top: -140,
              child: CreateEventBlurCircle(
                size: 260,
                color: Color(0x330961F6),
              ),
            ),
            Positioned(
              right: -140,
              bottom: -180,
              child: CreateEventBlurCircle(
                size: 320,
                color: AppColors.accent,
              ),
            ),
            SafeArea(
              top: false,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          _pageHorizontalPadding,
                          MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                          _pageHorizontalPadding,
                          128,
                        ),
                        children: <Widget>[
                          const CreateEventIntroCard(),
                          const SizedBox(height: 12),
                          CreateEventFormatCard(
                            isOnline: _isOnline,
                            onSetOnline: (value) {
                              setState(() {
                                _isOnline = value;
                                if (_isOnline) {
                                  _locationController.text = '';
                                  _latitude = null;
                                  _longitude = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          CreateEventPhotosSection(
                            decoration: _glassCardDecoration(),
                            uploadedPhotoUrls: _uploadedPhotoUrls,
                            pendingPhotoUploads: _pendingPhotoUploads,
                            isPhotoUploading: _isPhotoUploading,
                            maxEventPhotos: _maxEventPhotos,
                            onPickImages: _pickImages,
                            onRemoveUploadedPhoto: _removeUploadedPhoto,
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _glassCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _sectionHeader(
                                  icon: Icons.edit_rounded,
                                  title: 'Описание события',
                                  subtitle: 'Название, детали и категория',
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _titleController,
                                  decoration: _softInputDecoration(
                                    label: 'Название',
                                    hint: 'Например: Йога в парке',
                                    icon: Icons.event_rounded,
                                  ),
                                  validator: (String? value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Введите название события';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 4,
                                  decoration: _softInputDecoration(
                                    label: 'Описание',
                                    hint: 'Расскажите о формате, кому подойдёт, что взять с собой…',
                                    icon: Icons.notes_rounded,
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (String? value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Введите описание события';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Категория',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dark.withValues(alpha: 0.76),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _categories.map((c) {
                                    final selected = _selectedCategories.contains(c);
                                    return FilterChip(
                                      label: Text(
                                        c,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      selected: selected,
                                      onSelected: (_) {
                                        setState(() {
                                          if (selected) {
                                            if (_selectedCategories.length > 1 ||
                                                _customCategoryController.text.trim().isNotEmpty) {
                                              _selectedCategories.remove(c);
                                            }
                                          } else {
                                            _selectedCategories.add(c);
                                          }
                                        });
                                      },
                                      selectedColor:
                                          AppColors.primary.withValues(alpha: 0.16),
                                      backgroundColor:
                                          AppColors.surface.withValues(alpha: 0.62),
                                      checkmarkColor: AppColors.primary,
                                      side: BorderSide(
                                        color: selected
                                            ? AppColors.primary.withValues(alpha: 0.34)
                                            : AppColors.primary.withValues(alpha: 0.14),
                                      ),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.dark.withValues(alpha: 0.78),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 0,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _customCategoryController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _softInputDecoration(
                                    label: 'Своя категория',
                                    hint: 'Например: Псай-транс вечеринка',
                                    icon: Icons.category_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _glassCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _sectionHeader(
                                  icon: Icons.schedule_rounded,
                                  title: 'Когда',
                                  subtitle: 'Дата и время начала (и окончания при необходимости)',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectDate,
                                        borderRadius: BorderRadius.circular(16),
                                        child: InputDecorator(
                                          decoration: _softInputDecoration(
                                            label: 'Дата',
                                            icon: Icons.calendar_today_rounded,
                                          ),
                                          child: Text(
                                            DateFormat('dd.MM.yyyy').format(_selectedDate),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.dark.withValues(alpha: 0.82),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectTime,
                                        borderRadius: BorderRadius.circular(16),
                                        child: InputDecorator(
                                          decoration: _softInputDecoration(
                                            label: 'Время',
                                            icon: Icons.access_time_rounded,
                                          ),
                                          child: Text(
                                            _selectedTime.format(context),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.dark.withValues(alpha: 0.82),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(alpha: 0.50),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: SwitchListTile(
                                    title: Text(
                                      'Указать окончание',
                                      style: TextStyle(
                                        color: AppColors.dark.withValues(alpha: 0.84),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _hasEndDateTime
                                          ? 'Будет показано время окончания'
                                          : 'Полезно для расписания и поиска',
                                      style: TextStyle(
                                        color: AppColors.dark.withValues(alpha: 0.58),
                                      ),
                                    ),
                                    value: _hasEndDateTime,
                                    activeThumbColor: AppColors.primary,
                                    activeTrackColor:
                                        AppColors.primary.withValues(alpha: 0.22),
                                    onChanged: (bool value) {
                                      setState(() {
                                        _hasEndDateTime = value;
                                        if (_hasEndDateTime) {
                                          _selectedEndDate = _selectedDate;
                                          _selectedEndTime = _selectedTime;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  child: _hasEndDateTime
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 10),
                                          child: Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: InkWell(
                                                  onTap: _selectEndDate,
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: InputDecorator(
                                                    decoration: _softInputDecoration(
                                                      label: 'Дата окончания',
                                                      icon: Icons.event_available_rounded,
                                                    ),
                                                    child: Text(
                                                      DateFormat('dd.MM.yyyy').format(_selectedEndDate),
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.dark.withValues(alpha: 0.82),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: _selectEndTime,
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: InputDecorator(
                                                    decoration: _softInputDecoration(
                                                      label: 'Время окончания',
                                                      icon: Icons.more_time_rounded,
                                                    ),
                                                    child: Text(
                                                      _selectedEndTime.format(context),
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.dark.withValues(alpha: 0.82),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _glassCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _sectionHeader(
                                  icon: _isOnline ? Icons.videocam_rounded : Icons.place_rounded,
                                  title: 'Где и стоимость',
                                  subtitle: _isOnline ? 'Онлайн' : 'Локация и цена',
                                ),
                                const SizedBox(height: 12),
                                if (!_isOnline) ...<Widget>[
                                  TextFormField(
                                    controller: _locationController,
                                    readOnly: true,
                                    decoration: _softInputDecoration(
                                      label: 'Место проведения',
                                      hint: 'Выберите место на карте',
                                      icon: Icons.location_on_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          Icons.map_rounded,
                                          color: AppColors.primary.withValues(alpha: 0.86),
                                        ),
                                        onPressed: _openMapPicker,
                                      ),
                                    ),
                                    onTap: _openMapPicker,
                                    validator: (String? value) {
                                      if (!_isOnline && (value == null || value.isEmpty)) {
                                        return 'Укажите место проведения';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(alpha: 0.62),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: CreateEventSegmentButton(
                                          label: 'Бесплатно',
                                          icon: Icons.volunteer_activism_rounded,
                                          isSelected: _isFree,
                                          onTap: () {
                                            setState(() {
                                              _isFree = true;
                                              _priceController.text = '';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: CreateEventSegmentButton(
                                          label: 'Платно',
                                          icon: Icons.payments_rounded,
                                          isSelected: !_isFree,
                                          onTap: () => setState(() => _isFree = false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  child: _isFree
                                      ? const SizedBox.shrink()
                                      : TextFormField(
                                          controller: _priceController,
                                          keyboardType: TextInputType.number,
                                          decoration: _softInputDecoration(
                                            label: 'Цена (₽)',
                                            hint: 'Например: 500',
                                            icon: Icons.payments_rounded,
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
                  Positioned(
                    left: _pageHorizontalPadding,
                    right: _pageHorizontalPadding,
                    bottom: 12,
                    child: CreateEventBottomActionBar(
                      onPressed: _isLoading ? null : _handleCreateEvent,
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
                              'Создать событие',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
