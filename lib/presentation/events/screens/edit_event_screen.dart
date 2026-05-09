import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/custom_notification.dart';
import '../../../data/models/event_model.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import 'map_location_picker.dart';
import 'edit_event/edit_event_sections.dart';

class EditEventScreen extends StatefulWidget {
  final EventModel event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final List<String> _selectedCategories = <String>[];
  final _customCategoryController = TextEditingController();
  late bool _isOnline;
  bool _isPhotoUploading = false;
  bool _isLoading = false;

  final List<String> _uploadedPhotoUrls = <String>[];
  int _pendingPhotoUploads = 0;
  double? _latitude;
  double? _longitude;

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
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _locationController = TextEditingController(text: widget.event.location);
    _priceController = TextEditingController(text: widget.event.price.toString());
    
    _selectedDate = widget.event.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.event.dateTime);
    
    final existingCategories = widget.event.category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (final cat in existingCategories) {
      if (_categories.contains(cat)) {
        _selectedCategories.add(cat);
      } else {
        _customCategoryController.text = cat;
      }
    }
    if (_selectedCategories.isEmpty && _customCategoryController.text.isEmpty) {
      _selectedCategories.add('Спорт');
    }
    _isOnline = widget.event.isOnline;
    if (widget.event.imageUrls.isNotEmpty) {
      _uploadedPhotoUrls.addAll(widget.event.imageUrls);
    } else if ((widget.event.imageUrl ?? '').trim().isNotEmpty) {
      _uploadedPhotoUrls.add(widget.event.imageUrl!.trim());
    }
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final firstDate = selectedDateOnly.isBefore(today) ? selectedDateOnly : today;

    final maxDate = now.add(const Duration(days: 365));
    final lastDate = selectedDateOnly.isAfter(maxDate) ? selectedDateOnly : maxDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
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

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapLocationPicker(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationController.text = result['address'] as String;
        _latitude = result['latitude'] as double;
        _longitude = result['longitude'] as double;
      });
    }
  }

  void _updateEvent() {
    if (_formKey.currentState!.validate()) {
      if (_latitude == null || _longitude == null) {
        CustomNotification.show(
          context,
          'Пожалуйста, выберите местоположение на карте',
          isError: true,
        );
        return;
      }

      final DateTime dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final finalCategories = List<String>.from(_selectedCategories);
      if (_customCategoryController.text.trim().isNotEmpty) {
        finalCategories.add(_customCategoryController.text.trim());
      }

      context.read<EventBloc>().add(EventUpdateRequested(
        eventId: widget.event.id,
        title: _titleController.text,
        description: _descriptionController.text,
        category: finalCategories.join(', '),
        location: _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        dateTime: dateTime,
        price: double.tryParse(_priceController.text) ?? 0,
        imageUrl: _uploadedPhotoUrls.isEmpty ? null : _uploadedPhotoUrls.first,
        imageUrls: _uploadedPhotoUrls,
        isOnline: _isOnline,
      ));
    }
  }

  void _deleteEvent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: const Text('Вы уверены, что хотите удалить это событие? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EventBloc>().add(EventDeleteRequested(widget.event.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
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

  Widget _buildGradientCta({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.64 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              AppColors.primary,
              const Color(0xFF2E8BFF),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: child),
            ),
          ),
        ),
      ),
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
        } else if (state is EventUpdating || state is EventDeleting) {
          setState(() => _isLoading = true);
        } else if (state is EventUpdated) {
          setState(() => _isLoading = false);
          CustomNotification.show(context, 'Событие успешно обновлено');
          Navigator.pop(context, true); // Возвращаем true, чтобы обновить список
        } else if (state is EventDeleted) {
          setState(() => _isLoading = false);
          CustomNotification.show(context, 'Событие удалено');
          Navigator.pop(context, true); // Возвращаем true, чтобы обновить список
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
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: AppColors.dark.withValues(alpha: 0.78),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Редактирование',
            style: TextStyle(
              color: AppColors.dark.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
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
            children: [
              const Positioned(
                left: -120,
                top: -140,
                child: _BlurCircle(
                  size: 260,
                  color: Color(0x330961F6),
                ),
              ),
              Positioned(
                right: -140,
                bottom: -180,
                child: const _BlurCircle(
                  size: 320,
                  color: AppColors.accent,
                ),
              ),
              SafeArea(
                top: false,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      _pageHorizontalPadding,
                      MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                      _pageHorizontalPadding,
                      140,
                    ),
                    children: [
                      EditEventPhotosSection(
                        decoration: _glassCardDecoration(),
                        maxPhotos: _maxEventPhotos,
                        photoUrls: _uploadedPhotoUrls,
                        pendingUploads: _pendingPhotoUploads,
                        isUploading: _isPhotoUploading,
                        onPickImages: _pickImages,
                        onRemovePhoto: _removeUploadedPhoto,
                      ),
                      const SizedBox(height: 12),

                      EditEventDetailsSection(
                        decoration: _glassCardDecoration(),
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        customCategoryController: _customCategoryController,
                        categories: _categories,
                        selectedCategories: _selectedCategories,
                        onToggleCategory: (c) {
                          setState(() {
                            final selected = _selectedCategories.contains(c);
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
                        inputDecorationBuilder: ({
                          required String label,
                          String? hint,
                          IconData? icon,
                          Widget? suffix,
                          bool alignLabelWithHint = false,
                        }) {
                          return _softInputDecoration(
                            label: label,
                            hint: hint,
                            icon: icon,
                            suffix: suffix,
                            alignLabelWithHint: alignLabelWithHint,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      EditEventScheduleSection(
                        decoration: _glassCardDecoration(),
                        selectedDate: _selectedDate,
                        selectedTime: _selectedTime,
                        onPickDate: _selectDate,
                        onPickTime: _selectTime,
                        inputDecorationBuilder: ({
                          required String label,
                          String? hint,
                          IconData? icon,
                          Widget? suffix,
                          bool alignLabelWithHint = false,
                        }) {
                          return _softInputDecoration(
                            label: label,
                            hint: hint,
                            icon: icon,
                            suffix: suffix,
                            alignLabelWithHint: alignLabelWithHint,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      EditEventLocationPriceSection(
                        decoration: _glassCardDecoration(),
                        isOnline: _isOnline,
                        locationController: _locationController,
                        onOpenMapPicker: _pickLocation,
                        priceController: _priceController,
                        onToggleOnline: (value) {
                          setState(() {
                            _isOnline = value;
                          });
                        },
                        inputDecorationBuilder: ({
                          required String label,
                          String? hint,
                          IconData? icon,
                          Widget? suffix,
                          bool alignLabelWithHint = false,
                        }) {
                          return _softInputDecoration(
                            label: label,
                            hint: hint,
                            icon: icon,
                            suffix: suffix,
                            alignLabelWithHint: alignLabelWithHint,
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Кнопка удаления и сохранения...
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _deleteEvent,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Удалить'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildGradientCta(
                              onPressed: _isLoading ? null : _updateEvent,
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
                                      'Сохранить',
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(width: size, height: size, color: color),
      ),
    );
  }
}
