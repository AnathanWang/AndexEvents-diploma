import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class EventDetailSectionContainer extends StatelessWidget {
  const EventDetailSectionContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDFE7FF)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2F4E8A).withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EventDetailSectionTitle extends StatelessWidget {
  const EventDetailSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF243252),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF66739B),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class EventDetailInfoRow extends StatelessWidget {
  const EventDetailInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF5F76FF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF243252),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: Color(0xFF8EA0C5),
            ),
        ],
      ),
    );
  }
}

class EventDetailFloatingActionPanel extends StatelessWidget {
  const EventDetailFloatingActionPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: child,
        ),
      ),
    );
  }
}

class EventDetailFavoriteAction extends StatelessWidget {
  const EventDetailFavoriteAction({
    super.key,
    required this.isFavorite,
    required this.isLoading,
    required this.isDisabled,
    required this.onToggle,
  });

  final ValueListenable<bool> isFavorite;
  final ValueListenable<bool> isLoading;
  final bool isDisabled;
  final VoidCallback onToggle;

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
      child: ValueListenableBuilder<bool>(
        valueListenable: isFavorite,
        builder: (context, fav, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: isLoading,
            builder: (context, loading, __) {
              return IconButton(
                icon: Icon(
                  fav ? Icons.favorite : Icons.favorite_outline,
                  color:
                      fav ? const Color(0xFFDE5A77) : const Color(0xFF243252),
                ),
                onPressed: (loading || isDisabled) ? null : onToggle,
              );
            },
          );
        },
      ),
    );
  }
}

