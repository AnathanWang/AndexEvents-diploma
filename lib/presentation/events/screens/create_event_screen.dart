import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/common/custom_dropdown.dart';
import '../../widgets/common/custom_notification.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import 'map_location_picker.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedCategory = 'Спорт';
  bool _isOnline = false;
  bool _isPhotoUploading = false;
  bool _isLoading = false;
  
  File? _eventPhoto;
  String? _uploadedPhotoUrl;
  double? _latitude;
  double? _longitude;

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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _eventPhoto = File(image.path);
      });
      
      // Загружаем фото сразу
      if (mounted) {
        context.read<EventBloc>().add(EventPhotoUploadRequested(image.path));
      }
    }
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

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _locationController.text = result['address'];
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
      
      final price = double.tryParse(_priceController.text) ?? 0.0;
      
      // Для онлайн событий используем координаты по умолчанию (Москва)
      final lat = _isOnline ? 55.7558 : _latitude!;
      final lng = _isOnline ? 37.6173 : _longitude!;
      final location = _isOnline ? 'Онлайн' : _locationController.text;
      
      context.read<EventBloc>().add(
        EventCreateRequested(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          location: location,
          latitude: lat,
          longitude: lng,
          dateTime: dateTime,
          price: price,
          imageUrl: _uploadedPhotoUrl,
          isOnline: _isOnline,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EventBloc, EventState>(
      listener: (context, state) {
        if (state is EventPhotoUploading) {
          setState(() => _isPhotoUploading = true);
        } else if (state is EventPhotoUploaded) {
          setState(() {
            _isPhotoUploading = false;
            _uploadedPhotoUrl = state.photoUrl;
          });
          CustomNotification.show(context, 'Фото загружено!');
        } else if (state is EventCreating) {
          setState(() => _isLoading = true);
        } else if (state is EventCreated) {
          setState(() => _isLoading = false);
          Navigator.of(context).pop();
          CustomNotification.show(context, 'Событие успешно создано!');
        } else if (state is EventError) {
          setState(() {
            _isLoading = false;
            _isPhotoUploading = false;
          });
          CustomNotification.show(context, state.message, isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF4A4D6A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Создать событие',
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
            // Фото события
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  image: _eventPhoto != null
                      ? DecorationImage(
                          image: FileImage(_eventPhoto!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _eventPhoto == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: Color(0xFF9E9E9E),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Добавить фото',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Нажмите для загрузки',
                            style: TextStyle(
                              color: Color(0xFF5E60CE),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_isPhotoUploading)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Название события
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название события',
                hintText: 'Например: Йога в парке',
                prefixIcon: const Icon(Icons.event),
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
                  return 'Введите название события';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Описание
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Описание',
                hintText: 'Расскажите о вашем событии...',
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
                  return 'Введите описание события';
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
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Дата и время
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Дата',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Время',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                      child: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Переключатель онлайн/офлайн
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: const Text('Онлайн событие'),
                subtitle: Text(_isOnline ? 'Будет проходить онлайн' : 'Будет проходить оффлайн'),
                value: _isOnline,
                activeThumbColor: const Color(0xFF5E60CE),
                onChanged: (bool value) {
                  setState(() {
                    _isOnline = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Место проведения
            if (!_isOnline)
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Место проведения',
                  hintText: 'Выберите место на карте',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _openMapPicker,
                  ),
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
                onTap: _openMapPicker,
                validator: (String? value) {
                  if (!_isOnline && (value == null || value.isEmpty)) {
                    return 'Укажите место проведения';
                  }
                  return null;
                },
              ),
            if (!_isOnline) const SizedBox(height: 16),
            
            // Цена
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Цена (₽)',
                hintText: 'Оставьте пустым для бесплатного',
                prefixIcon: const Icon(Icons.payments),
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
            
            // Кнопка создания
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateEvent,
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
                      'Создать событие',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }
}
