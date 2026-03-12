import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/id_token_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/services/logger_service.dart';

/// Сервис для работы с Firebase Authentication
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final IdTokenProvider _idTokenProvider;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    IdTokenProvider? idTokenProvider,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
            ),
        _idTokenProvider = idTokenProvider ?? const IdTokenProvider() {
    LoggerService.info('[AuthService] Инициализирован (Firebase)');
  }

  /// Получить текущего пользователя Firebase
  User? get currentUser => _auth.currentUser;

  /// Stream для отслеживания изменений состояния авторизации
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Регистрация через Email и пароль
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Ошибка регистрации: пользователь не создан');
      }

      await user.updateDisplayName(displayName);
      await user.reload();

      await _createUserInBackend(
        displayName: displayName,
        photoUrl: user.photoURL,
      );

      // Автоматически отправляем verification email
      await user.sendEmailVerification();
      LoggerService.info('[AuthService] Verification email sent to $email');

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    } catch (e) {
      throw Exception('Ошибка регистрации: $e');
    }
  }

  /// Вход через Email и пароль
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _createUserInBackend(
          displayName: user.displayName ?? _displayNameFromEmail(user.email),
          photoUrl: user.photoURL,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }

  /// Вход через Google и получение статуса онбординга
  Future<Map<String, dynamic>> signInWithGoogleAndGetStatus() async {
    try {
      LoggerService.info('[Google Sign-In] Начинаем процесс входа...');

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In отменён пользователем');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Не удалось получить токены от Google');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка Google Sign-In: пользователь не найден');
      }

      await _createUserInBackend(
        displayName: user.displayName ?? googleUser.displayName ?? 'User',
        photoUrl: user.photoURL ?? googleUser.photoUrl,
      );

      bool isOnboardingCompleted = false;
      try {
        final profileData = await getCurrentUserProfile();
        isOnboardingCompleted = profileData['isOnboardingCompleted'] as bool? ?? false;
      } catch (e) {
        LoggerService.warning('[Google Sign-In] Не удалось получить статус онбординга', e);
        isOnboardingCompleted = false;
      }

      return {
        'userCredential': userCredential,
        'isOnboardingCompleted': isOnboardingCompleted,
      };
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    } catch (e) {
      LoggerService.error('[Google Sign-In] Exception', e);
      throw Exception('Ошибка входа через Google: $e');
    }
  }

  /// Выход из системы
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Получить Firebase ID Token для API запросов
  Future<String?> getIdToken() async {
    return _idTokenProvider.getIdToken();
  }

  /// Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    }
  }

  /// Проверка доступности email (не занят ли он)
  /// Возвращает true если email свободен, false если занят
  Future<bool> checkEmailAvailability(String email) async {
    try {
      final trimmedEmail = email.trim();
      final signInMethods = await _auth.fetchSignInMethodsForEmail(trimmedEmail);
      // Если список пустой - email свободен
      // Если есть методы входа - email уже зарегистрирован
      return signInMethods.isEmpty;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    } catch (e) {
      throw Exception('Ошибка проверки email: $e');
    }
  }

  /// Отправка письма для подтверждения email
  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      await user.sendEmailVerification();
      LoggerService.info('[AuthService] Verification email sent to ${user.email}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw Exception('Слишком много запросов. Подождите перед повторной отправкой');
      }
      throw Exception(_mapFirebaseAuthException(e));
    } catch (e) {
      throw Exception('Ошибка отправки письма: $e');
    }
  }

  /// Проверка подтвержден ли email
  bool get isEmailVerified {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Обновить данные пользователя (для проверки emailVerified статуса)
  Future<void> reloadUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      await user.reload();
      LoggerService.debug('[AuthService] User reloaded, emailVerified: ${user.emailVerified}');
    } catch (e) {
      throw Exception('Ошибка обновления пользователя: $e');
    }
  }

  /// Получить текущий профиль пользователя из бэкенда
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      LoggerService.info('[AuthService] Получение токена...');
      final token = await getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }
      
      LoggerService.info('[AuthService] Token получен, длина: ${token.length}');
      final url = '${AppConfig.baseUrl}/users/me';
      LoggerService.info('[AuthService] GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.receiveTimeout);

      LoggerService.info('[AuthService] Response status: ${response.statusCode}');
      LoggerService.debug('[AuthService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        LoggerService.info('[AuthService] Профиль успешно загружен');
        return data['data'] as Map<String, dynamic>;
      }

      throw Exception('Не удалось загрузить профиль пользователя (${response.statusCode}): ${response.body}');
    } on TimeoutException {
      LoggerService.error('[AuthService] Timeout при запросе к ${AppConfig.baseUrl}/users/me');
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Если вы на физическом устройстве, задайте API_BASE_URL через --dart-define.',
      );
    } on SocketException catch (e) {
      LoggerService.error('[AuthService] SocketException: ${e.message}');
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      LoggerService.error('[AuthService] Ошибка загрузки профиля', e);
      rethrow;
    }
  }

  Future<void> _createUserInBackend({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      LoggerService.info('[Backend] === НАЧАЛО создания пользователя в backend ===');
      LoggerService.info('[Backend] displayName=$displayName, photoUrl=$photoUrl');
      LoggerService.info('[Backend] baseUrl=${AppConfig.baseUrl}');
      
      final token = await getIdToken();
      LoggerService.info('[Backend] Token получен: ${token?.substring(0, 20) ?? "NULL"}...');
      
      if (token == null || token.isEmpty) {
        LoggerService.error('[Backend] ОШИБКА: Токен пустой или null');
        throw Exception('Не удалось получить токен авторизации');
      }
      
      final url = '${AppConfig.baseUrl}/users';
      LoggerService.info('[Backend] Полный URL: $url');
      LoggerService.info('[Backend] Отправка POST запроса...');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'displayName': displayName,
              'photoUrl': photoUrl,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              LoggerService.error('[Backend] TIMEOUT: Запрос превысил 15 секунд');
              throw Exception('Timeout: сервер не ответил за 15 секунд');
            },
          );

      LoggerService.info('[Backend] Response получен! Status: ${response.statusCode}');
      LoggerService.info('[Backend] Response headers: ${response.headers}');
      LoggerService.info('[Backend] Response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 409) {
        final error = 'Не удалось создать пользователя (${response.statusCode}): ${response.body}';
        LoggerService.error('[Backend] ОШИБКА: $error');
        throw Exception(error);
      }
      
      LoggerService.info('[Backend] === УСПЕХ: Пользователь создан в backend ===');
    } on http.ClientException catch (e) {
      LoggerService.error('[Backend] ClientException (сетевая ошибка)', e);
      rethrow;
    } on TimeoutException catch (e) {
      LoggerService.error('[Backend] TimeoutException', e);
      rethrow;
    } catch (e, stackTrace) {
      LoggerService.error('[Backend] Unexpected error создания пользователя', e);
      LoggerService.error('[Backend] StackTrace: $stackTrace');
      rethrow;
    }
  }

  String _displayNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return email.substring(0, at);
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    final code = e.code.toLowerCase();

    switch (code) {
      case 'invalid-email':
        return 'Некорректный формат email. Используйте формат: username@example.com';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль';
      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован. Попробуйте войти.';
      case 'weak-password':
        return 'Слишком простой пароль. Используйте минимум 6 символов.';
      case 'network-request-failed':
        return 'Ошибка сети. Проверьте подключение к интернету.';
      default:
        return e.message ?? 'Ошибка авторизации';
    }
  }
}
