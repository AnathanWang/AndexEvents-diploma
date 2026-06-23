import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_utils.dart';
import '../../../../data/models/event_model.dart';

class EventDetailSliverAppBar extends StatelessWidget {
  const EventDetailSliverAppBar({
    super.key,
    required this.event,
    required this.categoryColor,
    required this.imageGallery,
    required this.currentImageIndexListenable,
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
  final ValueListenable<int> currentImageIndexListenable;
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
          currentImageIndexListenable: currentImageIndexListenable,
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
    required this.currentImageIndexListenable,
    required this.onImageIndexChanged,
  });

  final Color categoryColor;
  final List<String> imageGallery;
  final ValueListenable<int> currentImageIndexListenable;
  final ValueChanged<int> onImageIndexChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentImageIndexListenable,
      builder: (context, currentIndex, _) {
        final safeIndex = imageGallery.isEmpty
            ? 0
            : currentIndex.clamp(0, imageGallery.length - 1);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (imageGallery.isNotEmpty)
              CachedNetworkImage(
                key: ValueKey<String>(imageGallery[safeIndex]),
                imageUrl: imageGallery[safeIndex],
                fit: BoxFit.cover,
                memCacheWidth: imageMemCachePx(300, context),
                placeholder: (context, url) => ColoredBox(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => _FallbackHero(
                  categoryColor: categoryColor,
                ),
              )
            else
              _FallbackHero(categoryColor: categoryColor),
            if (imageGallery.length > 1) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: safeIndex > 0
                        ? () => onImageIndexChanged(safeIndex - 1)
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: safeIndex < imageGallery.length - 1
                        ? () => onImageIndexChanged(safeIndex + 1)
                        : null,
                  ),
                ),
              ),
            ],
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
                          color: safeIndex == index
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GalleryNavButton extends StatelessWidget {
  const _GalleryNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: onTap == null ? 0.12 : 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
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

