import 'package:flutter/material.dart';

class PhotoGallerySheet extends StatefulWidget {
  final List<String> photos;
  final String? mainPhotoUrl;
  final int initialIndex;

  const PhotoGallerySheet({
    required this.photos,
    this.mainPhotoUrl,
    this.initialIndex = 0,
    super.key,
  });

  @override
  State<PhotoGallerySheet> createState() => _PhotoGallerySheetState();
}

class _PhotoGallerySheetState extends State<PhotoGallerySheet> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getAllPhotos() {
    final allPhotos = <String>[];
    if (widget.mainPhotoUrl?.isNotEmpty == true) {
      allPhotos.add(widget.mainPhotoUrl!);
    }
    allPhotos.addAll(widget.photos.where((p) => p != widget.mainPhotoUrl));
    return allPhotos;
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = _getAllPhotos();

    if (allPhotos.isEmpty) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
              child: Text('Нет фотографий'),
            ),
          );
        },
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Индикатор для закрытия
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // PageView с фотографиями
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: allPhotos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          allPhotos[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.image_not_supported),
                              ),
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
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Индикатор фотографий и счётчик
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // Точки-индикаторы
                    if (allPhotos.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          allPhotos.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentIndex == index
                                  ? const Color(0xFF5E60CE)
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Счётчик фотографий
                    Text(
                      '${_currentIndex + 1} / ${allPhotos.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4A4D6A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
