import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CreateEventBlurCircle extends StatelessWidget {
  const CreateEventBlurCircle({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: size,
          height: size,
          color: color,
        ),
      ),
    );
  }
}

class CreateEventSegmentButton extends StatelessWidget {
  const CreateEventSegmentButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isSelected
                ? LinearGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.primary.withValues(alpha: 0.10),
                    ],
                  )
                : null,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.34)
                  : AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.92)
                      : AppColors.dark.withValues(alpha: 0.64),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.dark.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateEventBottomActionBar extends StatelessWidget {
  const CreateEventBottomActionBar({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Opacity(
            opacity: onPressed == null ? 0.64 : 1,
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
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 14,
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
          ),
        ),
      ),
    );
  }
}

