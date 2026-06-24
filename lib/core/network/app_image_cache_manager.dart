import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// HTTP file fetcher with timeout + browser-like headers for external CDNs.
class TimeoutHttpFileService extends FileService {
  TimeoutHttpFileService({
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final Duration timeout;
  final http.Client _httpClient;

  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'AndexEvents/1.0',
    'Accept': 'image/*,*/*',
  };

  @override
  int concurrentFetches = 10;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(defaultHeaders);
    if (headers != null) {
      request.headers.addAll(headers);
    }

    final response = await _httpClient.send(request).timeout(timeout);
    return HttpGetResponse(response);
  }
}

/// Shared cache for [CachedNetworkImage] with bounded network waits.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const String cacheKey = 'andexAppImageCache';

  static final AppImageCacheManager instance = AppImageCacheManager._();

  AppImageCacheManager._()
      : super(
          Config(
            cacheKey,
            stalePeriod: const Duration(days: 3),
            maxNrOfCacheObjects: 250,
            fileService: TimeoutHttpFileService(),
          ),
        );
}
