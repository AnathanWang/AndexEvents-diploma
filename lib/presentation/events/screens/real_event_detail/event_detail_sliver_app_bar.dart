import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';

class EventDetailSliverAppBar extends StatelessWidget {
  const EventDetailSliverAppBar({
    super.key,
    required this.event,
    required this.categoryColor,
    required this.imageGallery,
    required this.currentImageIndex,
    required this.onImageIndexChanged,
    required this.favoriteAction,
    required this.onBack,
    required this.onReport,
    required this.onAddToCalendar,
    required this.onShare,
  });

  final EventModel event;
  final Color categoryColor;
  final List<String> imageGallery;
  final int currentImageIndex;
  final ValueChanged<int> onImageIndexChanged;

  final Widget favoriteAction;
  final VoidCallback onBack;
  final VoidCallback onReport;
  final VoidCallback onAddToCalendar;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      leading: _GlassCircleIconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF243252)),
        onPressed: onBack,
      ),
      actions: [
        favoriteAction,
        _GlassCircleIconButton(
          icon: const Icon(Icons.flag_rounded, color: Color(0xFF243252)),
          onPressed: onReport,
        ),
        _GlassCircleIconButton(
          icon: const Icon(
            Icons.event_available_rounded,
            color: Color(0xFF243252),
          ),
          onPressed: onAddToCalendar,
        ),
        _GlassCircleIconButton(
          icon: const Icon(Icons.share, color: Color(0xFF243252)),
          onPressed: onShare,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _GalleryBackground(
          categoryColor: categoryColor,
          imageGallery: imageGallery,
          currentImageIndex: currentImageIndex,
          onImageIndexChanged: onImageIndexChanged,
        ),
      ),
    );
  }
}

class _GlassCircleIconButton extends StatelessWidget {
  const _GlassCircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF365892).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}

class _GalleryBackground extends StatelessWidget {
  const _GalleryBackground({
    required this.categoryColor,
    required this.imageGallery,
    required this.currentImageIndex,
    required this.onImageIndexChanged,
  });

  final Color categoryColor;
  final List<String> imageGallery;
  final int currentImageIndex;
  final ValueChanged<int> onImageIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageGallery.isNotEmpty)
          PageView.builder(
            itemCount: imageGallery.length,
            onPageChanged: onImageIndexChanged,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: imageGallery[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => _FallbackHero(
                  categoryColor: categoryColor,
                ),
              );
            },
          )
        else
          _FallbackHero(categoryColor: categoryColor),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.46),
                ],
              ),
            ),
          ),
        ),
        if (imageGallery.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageGallery.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentImageIndex == index ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FallbackHero extends StatelessWidget {
  const _FallbackHero({required this.categoryColor});

  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.88),
            AppColors.primary.withValues(alpha: 0.64),
            AppColors.accent.withValues(alpha: 0.44),
          ],
        ),
      ),
      child: const Icon(
        Icons.event,
        size: 120,
        color: Colors.white38,
      ),
    );
  }
}

