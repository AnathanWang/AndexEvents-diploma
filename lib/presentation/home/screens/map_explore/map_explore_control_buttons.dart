import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class MapExploreControlButtons extends StatelessWidget {
  const MapExploreControlButtons({
    super.key,
    required this.bottom,
    required this.onCenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double bottom;
  final VoidCallback onCenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: bottom,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                icon: CupertinoIcons.location_fill,
                onTap: onCenter,
              ),
              const SizedBox(height: 8),
              _ControlButton(
                icon: CupertinoIcons.plus,
                onTap: onZoomIn,
              ),
              const SizedBox(height: 8),
              _ControlButton(
                icon: CupertinoIcons.minus,
                onTap: onZoomOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}
