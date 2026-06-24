import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/app_image_cache_manager.dart';
import '../../../core/utils/media_url_utils.dart';

/// Network image that rewrites upload URLs to the active API host.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.imageBuilder,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final ImageWidgetBuilder? imageBuilder;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)?
      errorWidget;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrlUtils.resolve(imageUrl);
    if (resolved.isEmpty) {
      return _fallback(context, resolved, Exception('empty image url'));
    }

    return CachedNetworkImage(
      key: ValueKey<String>(resolved),
      imageUrl: resolved,
      cacheManager: AppImageCacheManager.instance,
      httpHeaders: TimeoutHttpFileService.defaultHeaders,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      imageBuilder: imageBuilder,
      placeholder: placeholder,
      errorWidget:
          errorWidget ?? (context, url, error) => _fallback(context, url, error),
    );
  }

  Widget _fallback(BuildContext context, String url, Object error) {
    if (errorWidget != null) {
      return errorWidget!(context, url, error);
    }
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade500,
        size: (width != null && height != null)
            ? (width! < height! ? width! : height!) * 0.35
            : 32,
      ),
    );
  }
}
