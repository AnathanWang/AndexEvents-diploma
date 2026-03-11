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
      LoggerService.info('[Backend] Создание пользователя: displayName=$displayName');
      
      final token = await getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Не удалось получить токен авторизации');
      }
      
      LoggerService.debug('[Backend] Token получен, отправка запроса к ${AppConfig.baseUrl}/users');

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/users'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'displayName': displayName,
              'photoUrl': photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 10));

      LoggerService.info('[Backend] Response status: ${response.statusCode}');
      LoggerService.debug('[Backend] Response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 409) {
        throw Exception('Не удалось создать пользователя в базе данных (${response.statusCode}): ${response.body}');
      }
      
      LoggerService.info('[Backend] Пользователь успешно создан');
    } catch (e) {
      LoggerService.error('[Backend] Ошибка создания пользователя в backend', e);
      // Пробрасываем ошибку дальше чтобы AuthBloc мог обработать
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
