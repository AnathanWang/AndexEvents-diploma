import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Сервис для работы с Firebase Authentication
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Получить текущего пользователя Firebase
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream для отслеживания изменений состояния авторизации
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Регистрация через Email и пароль
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Создаём пользователя в Firebase
      final UserCredential credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Обновляем displayName
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();

      // Создаём пользователя в нашей базе данных
      if (credential.user != null) {
        await _createUserInBackend(
          firebaseUid: credential.user!.uid,
          email: email,
          displayName: displayName,
          photoUrl: null,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Вход через Email и пароль
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Вход через Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Запускаем процесс входа через Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In отменён пользователем');
      }

      // Получаем данные аутентификации
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Создаём credential для Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Входим в Firebase
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      // Проверяем, первый ли это вход (новый пользователь)
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Создаём пользователя в нашей базе данных
        await _createUserInBackend(
          firebaseUid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: userCredential.user!.displayName ?? 'User',
          photoUrl: userCredential.user!.photoURL,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Ошибка входа через Google: $e');
    }
  }

  /// Выход из системы
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Получить Firebase ID Token для API запросов
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  /// Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Получить текущий профиль пользователя из бэкенда
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Не удалось загрузить профиль пользователя');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки профиля: $e');
    }
  }

  /// Создание пользователя в нашей базе данных через backend API
  Future<void> _createUserInBackend({
    required String firebaseUid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firebaseUid': firebaseUid,
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 409) {
        // 409 = пользователь уже существует (это нормально при повторном входе)
        throw Exception('Не удалось создать пользователя в базе данных');
      }
    } catch (e) {
      // Логируем ошибку, но не бросаем - пользователь всё равно создан в Firebase
      print('Ошибка создания пользователя в backend: $e');
    }
  }

  /// Обработка Firebase ошибок с понятными сообщениями
  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Слишком слабый пароль. Используйте минимум 6 символов.';
      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован. Попробуйте войти.';
      case 'invalid-email':
        return 'Некорректный email адрес.';
      case 'user-not-found':
        return 'Пользователь с таким email не найден.';
      case 'wrong-password':
        return 'Неверный пароль.';
      case 'user-disabled':
        return 'Этот аккаунт заблокирован.';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже.';
      case 'operation-not-allowed':
        return 'Этот метод входа отключен. Обратитесь в поддержку.';
      default:
        return 'Ошибка авторизации: ${e.message}';
    }
  }
}
