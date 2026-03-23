import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/logger_service.dart';
import '../../widgets/common/custom_dropdown.dart';
import '../../widgets/common/custom_notification.dart';
import '../../../data/models/event_model.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import 'map_location_picker.dart';

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
  late String _selectedCategory;
  late bool _isOnline;
  bool _isPhotoUploading = false;
  bool _isLoading = false;

  final List<String> _uploadedPhotoUrls = <String>[];
  int _pendingPhotoUploads = 0;
  double? _latitude;
  double? _longitude;

  static const int _maxEventPhotos = 5;

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
    _selectedCategory = widget.event.category;
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5E60CE),
              onPrimary: Colors.white,
              surface: Colors.white,
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5E60CE),
              onPrimary: Colors.white,
              surface: Colors.white,
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

      context.read<EventBloc>().add(EventUpdateRequested(
        eventId: widget.event.id,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
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
        appBar: AppBar(
          title: const Text('Редактирование события'),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фото события
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _isPhotoUploading
                            ? const Center(child: CircularProgressIndicator())
                            : _uploadedPhotoUrls.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: CachedNetworkImage(
                                          imageUrl: _uploadedPhotoUrls.first,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                          errorWidget: (context, url, error) => const Icon(Icons.error),
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Изменить фото',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                      ),
                    ),
                    if (_uploadedPhotoUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uploadedPhotoUrls.length +
                              (_uploadedPhotoUrls.length + _pendingPhotoUploads < _maxEventPhotos ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == _uploadedPhotoUrls.length &&
                                _uploadedPhotoUrls.length + _pendingPhotoUploads < _maxEventPhotos) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Icon(Icons.add_a_photo_outlined),
                                ),
                              );
                            }

                            final url = _uploadedPhotoUrls[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                    placeholder: (context, _) => Container(
                                      width: 88,
                                      height: 88,
                                      color: Colors.grey.shade200,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, _, __) => Container(
                                      width: 88,
                                      height: 88,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeUploadedPhoto(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Название
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Название события',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите название';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Категория
                    CustomDropdown<String>(
                      label: 'Категория',
                      value: _selectedCategory,
                      prefixIcon: Icons.category,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Дата и время
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Дата',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              child: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Время',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.access_time),
                              ),
                              child: Text(_selectedTime.format(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Местоположение
                    TextFormField(
                      controller: _locationController,
                      readOnly: true,
                      onTap: _pickLocation,
                      decoration: InputDecoration(
                        labelText: 'Местоположение',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: const Icon(Icons.map),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, выберите местоположение';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Онлайн/Офлайн
                    SwitchListTile(
                      title: const Text('Онлайн событие'),
                      value: _isOnline,
                      onChanged: (bool value) {
                        setState(() {
                          _isOnline = value;
                        });
                      },
                      secondary: Icon(_isOnline ? Icons.videocam : Icons.people),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // Цена
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Цена (0 - бесплатно)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: '₽',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите цену';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Введите корректное число';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Описание
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Описание',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите описание';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Кнопки действий
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _deleteEvent,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _updateEvent,
                            icon: const Icon(Icons.save),
                            label: const Text('Сохранить'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF5E60CE),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
    );
  }
}
