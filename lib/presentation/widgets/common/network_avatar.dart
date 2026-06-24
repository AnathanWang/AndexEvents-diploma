import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/media_url_utils.dart';
import '../../../core/utils/performance_utils.dart';
import 'app_network_image.dart';

class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.url,
    required this.label,
    this.size = 44,
    this.fontSize = 14,
  });

  final String? url;
  final String label;
  final double size;
  final double fontSize;

  String get _initials {
    return label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = MediaUrlUtils.normalize(url?.trim());

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: normalized != null && normalized.isNotEmpty
          ? AppNetworkImage(
              imageUrl: normalized,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: imageMemCachePx(size, context),
              memCacheHeight: imageMemCachePx(size, context),
              errorWidget: (_, __, ___) => _initialsWidget(),
              placeholder: (_, __) => _initialsWidget(),
            )
          : _initialsWidget(),
    );
  }

  Widget _initialsWidget() {
    return Text(
      _initials.isEmpty ? '??' : _initials,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.primary.withValues(alpha: 0.92),
      ),
    );
  }
}
