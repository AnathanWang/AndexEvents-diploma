import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/auth/id_token_provider.dart';
import '../../core/services/logger_service.dart';
import '../models/admin_audit_log_model.dart';
import '../models/user_sanction_model.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';

/// Сервис для работы с профилем пользователя
class UserService {
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();
  late final LocalStorageService _storageService;

  Future<http.Response> _with429Retry(
    Future<http.Response> Function() send, {
    int maxAttempts = 3,
  }) async {
    http.Response? lastResponse;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final response = await send();
      lastResponse = response;

      if (response.statusCode != 429) {
        return response;
      }

      if (attempt == maxAttempts) {
        return response;
      }

      final retryAfterRaw =
          response.headers['retry-after'] ?? response.headers['Retry-After'];
      final retryAfterSeconds = int.tryParse((retryAfterRaw ?? '').trim());
      final baseDelayMs = 400 * (1 << (attempt - 1));
      final jitterMs = math.Random().nextInt(200);
      final delay =
          retryAfterSeconds != null
              ? Duration(seconds: retryAfterSeconds)
              : Duration(milliseconds: baseDelayMs + jitterMs);

      LoggerService.warning(
        '[UserService] 429 Too Many Requests. Retry in ${delay.inMilliseconds}ms (attempt $attempt/$maxAttempts)',
      );
      await Future.delayed(delay);
    }

    return lastResponse ?? await send();
  }

  UserService() {
    _storageService = LocalStorageService();
  }

  /// Получить Firebase ID Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final token = await _idTokenProvider.getIdToken(maxAttempts: 1);
      if (token != null && token.isNotEmpty) {
        return token;
      }
      LoggerService.warning('[UserService] Ожидание Firebase токена, попытка ${attempt + 1}/10...');
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _idTokenProvider.getIdToken();
  }

  /// Загрузить фото в локальное хранилище
  Future<String> uploadProfilePhoto(File photoFile) async {
    try {
      LoggerService.info('[UserService] Начинаем загрузку фото профиля...');
      LoggerService.info('[UserService] Размер файла: ${photoFile.lengthSync()} bytes');
      LoggerService.info('[UserService] Путь файла: ${photoFile.path}');

      final url = await _storageService.uploadProfilePhoto(
        photoFile.path,
        onProgress: (progress) {
          LoggerService.debug(
            '[UserService] Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      LoggerService.info('[UserService] Фото профиля успешно загружено: $url');
      return url;
    } on TimeoutException {
      LoggerService.error('[UserService] Таймаут при загрузке фото');
      rethrow;
    } on SocketException catch (e) {
      LoggerService.error('[UserService] Ошибка подключения при загрузке фото: $e');
      rethrow;
    } catch (e) {
      LoggerService.error('[UserService] Ошибка при загрузке фото профиля: $e');
      rethrow;
    }
  }

  /// Загрузить дополнительное фото профиля
  Future<String> uploadAdditionalPhoto(File photoFile) async {
    try {
      LoggerService.info('[UserService] Начинаем загрузку дополнительного фото...');
      LoggerService.info('[UserService] Размер файла: ${photoFile.lengthSync()} bytes');

      final url = await _storageService.uploadAdditionalPhoto(
        photoFile.path,
        onProgress: (progress) {
          LoggerService.debug(
            '[UserService] Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      LoggerService.info('[UserService] Дополнительное фото успешно загружено: $url');
      return url;
    } on TimeoutException {
      LoggerService.error('[UserService] Таймаут при загрузке фото');
      rethrow;
    } on SocketException catch (e) {
      LoggerService.error('[UserService] Ошибка подключения при загрузке фото: $e');
      rethrow;
    } catch (e) {
      LoggerService.error('[UserService] Ошибка при загрузке дополнительного фото: $e');
      rethrow;
    }
  }

  Future<String> uploadCoverPhoto(File photoFile) async {
    try {
      LoggerService.info('[UserService] Начинаем загрузку обложки профиля...');
      LoggerService.info('[UserService] Размер файла: ${photoFile.lengthSync()} bytes');

      final url = await _storageService.uploadCoverPhoto(
        photoFile.path,
        onProgress: (progress) {
          LoggerService.debug(
            '[UserService] Cover upload progress: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      LoggerService.info('[UserService] Обложка профиля успешно загружена: $url');
      return url;
    } on TimeoutException {
      LoggerService.error('[UserService] Таймаут при загрузке обложки');
      rethrow;
    } on SocketException catch (e) {
      LoggerService.error('[UserService] Ошибка подключения при загрузке обложки: $e');
      rethrow;
    } catch (e) {
      LoggerService.error('[UserService] Ошибка при загрузке обложки: $e');
      rethrow;
    }
  }

  /// Удалить фото профиля
  Future<void> deleteAdditionalPhoto(String photoUrl) async {
    try {
      LoggerService.info('[UserService] Удаляем фото...');
      await _storageService.deletePhoto(photoUrl);
      LoggerService.info('[UserService] Фото успешно удалено');
    } catch (e) {
      LoggerService.error('[UserService] Ошибка при удалении фото: $e');
      rethrow;
    }
  }

  /// Обновить профиль пользователя
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? coverImageUrl,
    List<String>? photos,
    String? bio,
    int? age,
    String? gender,
    List<String>? interests,
    Map<String, String>? socialLinks,
    bool? isOnboardingCompleted,
    bool? showVisitedEvents,
    bool? showInMatches,
    bool? incognitoMode,
    bool? hideOnlineStatus,
    String? fcmToken,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      LoggerService.debug('[UserService] Token получен, длина: ${token.length}');

      final Map<String, dynamic> body = {};
      if (displayName != null) body['displayName'] = displayName;
      if (photoUrl != null) body['photoUrl'] = photoUrl;
      if (coverImageUrl != null) body['coverImageUrl'] = coverImageUrl;
      if (photos != null) body['photos'] = photos;
      if (bio != null) body['bio'] = bio;
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender;
      if (interests != null) body['interests'] = interests;
      if (socialLinks != null) body['socialLinks'] = socialLinks;
      if (isOnboardingCompleted != null) {
        body['isOnboardingCompleted'] = isOnboardingCompleted;
      }
      if (showVisitedEvents != null) body['showVisitedEvents'] = showVisitedEvents;
      if (showInMatches != null) body['showInMatches'] = showInMatches;
      if (incognitoMode != null) body['incognitoMode'] = incognitoMode;
      if (hideOnlineStatus != null) body['hideOnlineStatus'] = hideOnlineStatus;
      if (fcmToken != null) body['fcmToken'] = fcmToken;

      final url = '${AppConfig.baseUrl}/users/me';
      LoggerService.info('[UserService] PUT $url with body: ${json.encode(body)}');
      LoggerService.debug('[UserService] PUT $url');
      LoggerService.debug(
        '[UserService] updateProfile payload keys: ${body.keys.toList()}',
      );
      LoggerService.debug(
        '[UserService] updateProfile coverImageUrl: ${body['coverImageUrl']}',
      );

      final response = await http
          .put(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(AppConfig.receiveTimeout);

      LoggerService.debug('[UserService] Ответ статус: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления профиля');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Если вы на физическом устройстве, укажите IP компьютера через '
        '--dart-define=API_BASE_URL=http://<IP>/api',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}. '
        'Проверьте что backend запущен и устройство в той же сети.',
      );
    } catch (e) {
      throw Exception('Не удалось обновить профиль: $e');
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    if (fcmToken.trim().isEmpty) return;
    await updateProfile(fcmToken: fcmToken.trim());
  }

  /// Обновить геолокацию пользователя
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/me/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления локации');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Проверьте доступность backend и правильность адреса.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      throw Exception('Не удалось обновить локацию: $e');
    }
  }

  /// Получить текущий профиль пользователя
  Future<UserModel> getCurrentUser() async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userJson = data['data'] as Map<String, dynamic>;
        LoggerService.debug(
          '[UserService] GET /users/me raw coverImageUrl: ${userJson['coverImageUrl']}',
        );

        final user = UserModel.fromJson(userJson);
        LoggerService.debug(
          '[UserService] GET /users/me normalized coverImageUrl: ${user.coverImageUrl}',
        );
        return user;
      } else {
        throw Exception('Не удалось получить профиль');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Проверьте доступность backend и правильность адреса.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      throw Exception('Ошибка получения профиля: $e');
    }
  }

  /// Получить список других пользователей для матчей
  Future<List<UserModel>> getOtherUsers({
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radiusKm = 50,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final params = <String, dynamic>{'limit': limit};

      if (latitude != null && longitude != null && radiusKm != null) {
        params['latitude'] = latitude;
        params['longitude'] = longitude;
        params['radiusKm'] = radiusKm;
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/users/matches${_buildQueryString(params)}',
      );

      final response = await _with429Retry(
        () => http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = json['data'] as List<dynamic>?;

        final users =
            usersList?.map((user) {
              try {
                return UserModel.fromJson(user as Map<String, dynamic>);
              } catch (e) {
                LoggerService.error('[UserService] Ошибка при парсинге пользователя', e);
                rethrow;
              }
            }).toList() ??
            [];

        return users;
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else if (response.statusCode == 404) {
        LoggerService.warning('[UserService] Endpoint вернул 404 — пользователи не найдены');
        return [];
      } else if (response.statusCode == 429) {
        throw Exception('Слишком много запросов. Попробуйте чуть позже.');
      } else {
        throw Exception(
          'Ошибка при получении пользователей: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Проверьте доступность backend.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      LoggerService.error('[UserService] Ошибка при получении пользователей', e);
      throw Exception('Ошибка получения пользователей: $e');
    }
  }

  /// Получить полный список пользователей для модерации
  Future<List<UserModel>> getUsersForModeration() async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await _with429Retry(
        () => http
            .get(
              Uri.parse('${AppConfig.baseUrl}/users'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(AppConfig.receiveTimeout),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = json['data'] as List<dynamic>?;

        return usersList
                ?.map((u) => UserModel.fromJson(u as Map<String, dynamic>))
                .toList() ??
            [];
      }

      if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      }

      if (response.statusCode == 403) {
        throw Exception('Недостаточно прав для доступа к модерации');
      }

      throw Exception(
        'Ошибка получения пользователей модерации: ${response.statusCode}',
      );
    } on TimeoutException {
      throw Exception('Таймаут при загрузке пользователей модерации');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading moderation users', e);
      rethrow;
    }
  }

  /// Получить пользователя по id
  Future<UserModel> getUserById(String userId) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userJson = data['data'] as Map<String, dynamic>;
        return UserModel.fromJson(userJson);
      }

      throw Exception('Не удалось получить пользователя: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Таймаут при получении пользователя');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading user by id ($userId)', e);
      rethrow;
    }
  }

  /// Получить взаимные матчи (пользователи, с которыми есть mutual like)
  Future<List<UserModel>> getMutualMatches({
    int limit = 50,
    String? eventId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      // На бэкенде: GET /api/matches -> отдаёт список пользователей
      final query = <String, String>{'limit': '$limit'};
      if (eventId != null && eventId.trim().isNotEmpty) {
        query['eventId'] = eventId.trim();
      }
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/matches',
      ).replace(queryParameters: query);
      final response = await _with429Retry(
        () => http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = json['data'] as List<dynamic>?;
        return usersList
                ?.map((u) => UserModel.fromJson(u as Map<String, dynamic>))
                .toList() ??
            [];
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else if (response.statusCode == 429) {
        throw Exception('Слишком много запросов. Попробуйте чуть позже.');
      } else {
        throw Exception(
          'Ошибка при получении взаимных матчей: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Таймаут при получении взаимных матчей');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading mutual matches', e);
      rethrow;
    }
  }

  /// Получить пользователей по действию (LIKE / DISLIKE / SUPER_LIKE)
  Future<List<UserModel>> getUsersByMatchAction({
    required String action,
    int limit = 50,
    String? eventId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final query = <String, String>{
        'action': action,
        'limit': '$limit',
      };
      if (eventId != null && eventId.trim().isNotEmpty) {
        query['eventId'] = eventId.trim();
      }
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/matches/actions',
      ).replace(queryParameters: query);

      final response = await _with429Retry(
        () => http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = json['data'] as List<dynamic>?;
        return usersList
                ?.map((u) => UserModel.fromJson(u as Map<String, dynamic>))
                .toList() ??
            [];
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else if (response.statusCode == 429) {
        throw Exception('Слишком много запросов. Попробуйте чуть позже.');
      } else {
        throw Exception(
          'Ошибка при получении списка по действию $action: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Таймаут при запросе к API (${AppConfig.baseUrl}).');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading match action list ($action)', e);
      rethrow;
    }
  }

  /// Получить пользователей, которые лайкнули меня, но я еще не ответил
  Future<List<UserModel>> getIncomingLikes({
    int limit = 50,
    String? eventId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final query = <String, String>{'limit': '$limit'};
      if (eventId != null && eventId.trim().isNotEmpty) {
        query['eventId'] = eventId.trim();
      }
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/matches/incoming-likes',
      ).replace(queryParameters: query);

      final response = await _with429Retry(
        () => http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = json['data'] as List<dynamic>?;
        return usersList
                ?.map((u) => UserModel.fromJson(u as Map<String, dynamic>))
                .toList() ??
            [];
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else if (response.statusCode == 429) {
        throw Exception('Слишком много запросов. Попробуйте чуть позже.');
      } else {
        throw Exception(
          'Ошибка при получении входящих лайков: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Таймаут при запросе к API (${AppConfig.baseUrl}).');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading incoming likes', e);
      rethrow;
    }
  }

  /// Построить query string из параметров
  String _buildQueryString(Map<String, dynamic> params) {
    if (params.isEmpty) return '';

    final queryParts = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .toList();

    return '?${queryParts.join('&')}';
  }

  String _extractApiErrorMessage(http.Response response, String fallback) {
    try {
      final payload = json.decode(response.body);
      if (payload is Map<String, dynamic>) {
        final message = payload['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        final error = payload['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
      // Ignore JSON parse issues and return fallback message.
    }
    return fallback;
  }

  /// Отправить лайк на сервер
  Future<void> sendLike(String targetUserId, {String? eventId}) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final body = <String, dynamic>{'targetUserId': targetUserId};
      if (eventId != null) {
        body['eventId'] = eventId;
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/matches/like'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.info('[UserService] Like sent to $targetUserId');
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else {
        final apiMessage = _extractApiErrorMessage(
          response,
          'Ошибка при отправке лайка',
        );
        LoggerService.error(
          '[UserService] Error sending like: ${response.statusCode}, body=${response.body}',
        );
        throw Exception('$apiMessage (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Таймаут при отправке лайка');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error sending like', e);
      rethrow;
    }
  }

  /// Отправить дизлайк на сервер
  Future<void> sendDislike(String targetUserId, {String? eventId}) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final body = <String, dynamic>{'targetUserId': targetUserId};
      if (eventId != null) {
        body['eventId'] = eventId;
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/matches/dislike'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.info('[UserService] Dislike sent to $targetUserId');
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else {
        final apiMessage = _extractApiErrorMessage(
          response,
          'Ошибка при отправке дизлайка',
        );
        LoggerService.error(
          '[UserService] Error sending dislike: ${response.statusCode}, body=${response.body}',
        );
        throw Exception('$apiMessage (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Таймаут при отправке дизлайка');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error sending dislike', e);
      rethrow;
    }
  }

  /// Отправить супер-лайк на сервер
  Future<void> sendSuperLike(String targetUserId, {String? eventId}) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final body = <String, dynamic>{'targetUserId': targetUserId};
      if (eventId != null) {
        body['eventId'] = eventId;
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/matches/super-like'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.info('[UserService] Super like sent to $targetUserId');
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else {
        final apiMessage = _extractApiErrorMessage(
          response,
          'Ошибка при отправке супер-лайка',
        );
        LoggerService.error(
          '[UserService] Error sending super like: ${response.statusCode}, body=${response.body}',
        );
        throw Exception('$apiMessage (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Таймаут при отправке супер-лайка');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error sending super like', e);
      rethrow;
    }
  }

  Future<void> blockUser(String targetUserId) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/users/me/blocks'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'targetUserId': targetUserId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.info('[UserService] User blocked: $targetUserId');
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(data['message'] ?? 'Некорректный запрос');
      } else if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      } else {
        throw Exception('Ошибка блокировки пользователя: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Таймаут при блокировке пользователя');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error blocking user', e);
      rethrow;
    }
  }

  Future<void> updateUserRole({
    required String targetUserId,
    required String role,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/$targetUserId/role'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'role': role}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        LoggerService.info('[UserService] User role updated: $targetUserId -> $role');
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['message'] ?? 'Ошибка смены роли';

      if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      }

      if (response.statusCode == 403) {
        throw Exception('Недостаточно прав для смены роли');
      }

      throw Exception('$message (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Таймаут при смене роли пользователя');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error updating user role', e);
      rethrow;
    }
  }

  Future<List<AdminAuditLogModel>> getAdminAuditLogs({int limit = 100}) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/admin/audit-logs?limit=$limit'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rows = data['data'] as List<dynamic>? ?? const <dynamic>[];
        return rows
            .map(
              (row) => AdminAuditLogModel.fromJson(
                row as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      }

      if (response.statusCode == 403) {
        throw Exception('Недостаточно прав для просмотра журнала');
      }

      throw Exception('Ошибка загрузки журнала: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Таймаут при загрузке журнала');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading admin audit logs', e);
      rethrow;
    }
  }

  Future<List<UserSanctionModel>> getAdminSanctions({
    String? targetUserId,
    int limit = 200,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final query = <String, String>{'limit': '$limit'};
      if (targetUserId != null && targetUserId.isNotEmpty) {
        query['targetUserId'] = targetUserId;
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/users/admin/sanctions',
      ).replace(queryParameters: query);

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rows = data['data'] as List<dynamic>? ?? const <dynamic>[];
        return rows
            .map((row) => UserSanctionModel.fromJson(row as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      }

      if (response.statusCode == 403) {
        throw Exception('Недостаточно прав для просмотра санкций');
      }

      throw Exception('Ошибка загрузки санкций: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Таймаут при загрузке санкций');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading sanctions', e);
      rethrow;
    }
  }

  Future<List<UserSanctionModel>> getMySanctions() async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/me/sanctions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rows = data['data'] as List<dynamic>? ?? const <dynamic>[];
        return rows
            .map((row) => UserSanctionModel.fromJson(row as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Истекла сессия авторизации');
      }

      throw Exception('Ошибка загрузки моих санкций: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Таймаут при загрузке моих санкций');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error loading my sanctions', e);
      rethrow;
    }
  }

  Future<void> createUserSanction({
    required String targetUserId,
    required String type,
    required String reason,
    DateTime? expiresAt,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/users/admin/sanctions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'targetUserId': targetUserId,
              'type': type,
              'reason': reason,
              'expiresAt': expiresAt?.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.info('[UserService] User sanction created: $targetUserId -> $type');
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['message'] ?? 'Ошибка создания санкции';
      throw Exception('$message (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Таймаут при создании санкции');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error creating user sanction', e);
      rethrow;
    }
  }

  Future<void> revokeUserSanction(String sanctionId) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/admin/sanctions/$sanctionId/revoke'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        LoggerService.info('[UserService] User sanction revoked: $sanctionId');
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['message'] ?? 'Ошибка отзыва санкции';
      throw Exception('$message (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Таймаут при отзыве санкции');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[UserService] Error revoking user sanction', e);
      rethrow;
    }
  }
}
