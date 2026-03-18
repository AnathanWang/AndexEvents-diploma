import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';

class PhotoGallerySheet extends StatefulWidget {
  final List<String> photos;
  final String? mainPhotoUrl;
  final int initialIndex;
  final double initialAvatarSize;
  final Rect? sourceRect;

  const PhotoGallerySheet({
    required this.photos,
    this.mainPhotoUrl,
    this.initialIndex = 0,
    this.initialAvatarSize = 120,
    this.sourceRect,
    super.key,
  });

  @override
  State<PhotoGallerySheet> createState() => _PhotoGallerySheetState();
}

class _PhotoGallerySheetState extends State<PhotoGallerySheet>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late int _currentIndex;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  Future<void> _closeWithAnimation() async {
    if (_isClosing) return;
    _isClosing = true;
    await _animationController.reverse();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildGalleryImage(String path) {
    final isNetworkImage =
        path.startsWith('http://') || path.startsWith('https://');

    if (isNetworkImage) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF1E1E1E),
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.white70,
                size: 48,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1E1E1E),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF1E1E1E),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.white70,
              size: 48,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = _getAllPhotos();
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final targetSize = size.width - 40;
    final targetRect = Rect.fromLTWH(
      20,
      padding.top + ((size.height - padding.top - padding.bottom - targetSize) / 2),
      targetSize,
      targetSize,
    );
    final startRect =
        widget.sourceRect ??
        Rect.fromCenter(
          center: targetRect.center,
          width: widget.initialAvatarSize,
          height: widget.initialAvatarSize,
        );

    if (allPhotos.isEmpty) {
      return WillPopScope(
        onWillPop: () async {
          await _closeWithAnimation();
          return false;
        },
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return Material(
              color: Colors.black.withValues(alpha: 0.92 * _animation.value),
              child: SafeArea(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _closeWithAnimation,
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Нет фотографий',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Opacity(
                        opacity: _animation.value,
                        child: IconButton(
                          onPressed: _closeWithAnimation,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _closeWithAnimation();
        return false;
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = _animation.value;
          final currentRect = Rect.lerp(startRect, targetRect, value) ?? targetRect;
          final currentRadius = (startRect.width / 2) + (24 - (startRect.width / 2)) * value;
          final double photoOpacity =
              value < 0.08 ? ((value / 0.08).clamp(0.0, 1.0)).toDouble() : 1.0;
          final overlayOpacity = ((value - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();

          return Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withValues(alpha: 0.82 * value),
              child: SafeArea(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 10 * value,
                          sigmaY: 10 * value,
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.12 * value),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _closeWithAnimation,
                      ),
                    ),
                    Positioned(
                      left: currentRect.left,
                      top: currentRect.top,
                      width: currentRect.width,
                      height: currentRect.height,
                      child: Opacity(
                        opacity: photoOpacity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(currentRadius),
                          child: child,
                        ),
                      ),
                    ),
                    if (value > 0.7)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Opacity(
                          opacity: overlayOpacity,
                          child: IconButton(
                            onPressed: _closeWithAnimation,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                    if (value > 0.7)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Opacity(
                          opacity: overlayOpacity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${allPhotos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (value > 0.7 && allPhotos.length > 1)
                      Positioned(
                        right: 0,
                        bottom: 36,
                        left: 0,
                        child: Opacity(
                          opacity: overlayOpacity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              allPhotos.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: _currentIndex == index ? 18 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: _currentIndex == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.35),
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
          );
        },
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemCount: allPhotos.length,
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: _buildGalleryImage(allPhotos[index]),
            );
          },
        ),
      ),
    );
  }
}
