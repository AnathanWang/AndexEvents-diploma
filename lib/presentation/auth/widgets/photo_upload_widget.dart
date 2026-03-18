import 'package:flutter/material.dart';
import 'dart:io';

class PhotoUploadWidget extends StatefulWidget {
  final List<String> uploadedPhotos;
  final List<File>? selectedPhotoFiles;
  final Function(File) onPhotoSelected;
  final Function(String) onPhotoRemoved;
  final Function(List<File>) onPhotosUpdated;

  const PhotoUploadWidget({
    required this.uploadedPhotos,
    required this.selectedPhotoFiles,
    required this.onPhotoSelected,
    required this.onPhotoRemoved,
    required this.onPhotosUpdated,
    super.key,
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  late List<File> _localFiles;

  @override
  void initState() {
    super.initState();
    _localFiles = widget.selectedPhotoFiles ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = [
      ...widget.uploadedPhotos,
      ..._localFiles.map((f) => f.path),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Ваши фотографии',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4D6A),
            ),
          ),
        ),
        // Сетка фотографий
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: allPhotos.length + 1,
          itemBuilder: (context, index) {
            if (index == allPhotos.length) {
              // Кнопка добавления
              return GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF5E60CE).withValues(alpha: 0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 32,
                        color: Color(0xFF5E60CE),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5E60CE),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final photoPath = allPhotos[index];
            final isNetworkImage = photoPath.startsWith('http');

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Изображение
                  isNetworkImage
                      ? Image.network(
                          photoPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                  // Кнопка удаления
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${allPhotos.length} из 5 фотографий',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePhotoOption('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePhotoOption('gallery');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePhotoOption(String option) {
    // Здесь будет интеграция с image_picker
    // На данный момент оставляем как заглушку
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Функция $option будет реализована')),
    );
  }

  void _removePhoto(int index) {
    if (index < widget.uploadedPhotos.length) {
      // Удаление загруженной фотографии
      widget.onPhotoRemoved(widget.uploadedPhotos[index]);
    } else {
      // Удаление локальной фотографии
      final fileIndex = index - widget.uploadedPhotos.length;
      _localFiles.removeAt(fileIndex);
      widget.onPhotosUpdated(_localFiles);
    }
    setState(() {});
  }
}
