import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Сервис для работы с Firebase Authentication
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    print('🔵 [AuthService] Инициализирован');
    
    // Инициализируем GoogleSignIn с явным clientId для iOS
    // На iOS необходимо явно указать clientId, чтобы GoogleSignIn знал, какой OAuth client использовать
    // На Android это берётся из google-services.json автоматически
    // clientId находится в GoogleService-Info.plist (CLIENT_ID)
    _googleSignIn = GoogleSignIn(
      clientId: '672417054710-2gm36ur4k2nj5a7ed2re974mmq4qmt34.apps.googleusercontent.com',
      scopes: [
        'email',
        'profile',
      ],
    );
    print('🔵 [AuthService] GoogleSignIn инициализирован с clientId и scopes: email, profile');
  }

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
      print('🔵 [Google Sign-In] Начинаем процесс входа...');
      
      // Сначала проверяем, уже ли пользователь авторизован
      final GoogleSignInAccount? alreadySignedIn = await _googleSignIn.signInSilently();
      print('🔵 [Google Sign-In] Уже авторизован? ${alreadySignedIn?.email}');
      
      // Запускаем процесс входа через Google
      print('🔵 [Google Sign-In] Вызываем signIn()...');
      print('🔵 [Google Sign-In] GoogleSignIn currentUser: ${_googleSignIn.currentUser?.email}');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('🔴 [Google Sign-In] Timeout при вызове signIn()');
          throw Exception('Google Sign-In timeout after 60 seconds');
        },
      ).catchError((error) {
        print('🔴 [Google Sign-In] Error при signIn: $error');
        throw Exception('Google Sign-In error: $error');
      });
      
      print('🔵 [Google Sign-In] Получен googleUser: ${googleUser?.email}');

      if (googleUser == null) {
        print('🔴 [Google Sign-In] Пользователь отменил вход или signIn() вернул null');
        throw Exception('Google Sign-In отменён пользователем');
      }

      // Получаем данные аутентификации
      print('🔵 [Google Sign-In] Получаем токены...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('🔵 [Google Sign-In] Токены получены: accessToken=${googleAuth.accessToken != null}, idToken=${googleAuth.idToken != null}');

      // Проверяем, что у нас есть токены
      if (googleAuth.idToken == null) {
        print('🔴 [Google Sign-In] idToken == null!');
        throw Exception('Не удалось получить idToken от Google');
      }

      // Создаём credential для Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('🔵 [Google Sign-In] Credential создан');

      // Входим в Firebase
      print('🔵 [Google Sign-In] Входим в Firebase...');
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      print('🔵 [Google Sign-In] Вход в Firebase успешен: ${userCredential.user?.email}');

      // Проверяем, первый ли это вход (новый пользователь)
      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      print('🔵 [Google Sign-In] Новый пользователь? $isNewUser');
      
      if (isNewUser) {
        print('🔵 [Google Sign-In] Создаём пользователя в backend...');
        // Создаём пользователя в нашей базе данных
        await _createUserInBackend(
          firebaseUid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: userCredential.user!.displayName ?? 'User',
          photoUrl: userCredential.user!.photoURL,
        );
        print('🔵 [Google Sign-In] Пользователь создан в backend');
      }

      print('🔵 [Google Sign-In] Успех!');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('🔴 [Google Sign-In] FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('🔴 [Google Sign-In] Exception: $e\n${StackTrace.current}');
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
      print('🔵 [Backend] Отправляем POST запрос на ${AppConfig.baseUrl}/users');
      print('🔵 [Backend] Данные: firebaseUid=$firebaseUid, email=$email, displayName=$displayName');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firebaseUid': firebaseUid,
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('🔴 [Backend] Timeout при создании пользователя');
          throw Exception('Timeout при подключении к backend');
        },
      );

      print('🔵 [Backend] Response status: ${response.statusCode}');
      print('🔵 [Backend] Response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 409) {
        // 409 = пользователь уже существует (это нормально при повторном входе)
        throw Exception('Не удалось создать пользователя в базе данных (${response.statusCode})');
      }
      print('🔵 [Backend] Пользователь успешно создан');
    } catch (e) {
      // Логируем ошибку, но не бросаем - пользователь всё равно создан в Firebase
      print('🔴 [Backend] Ошибка создания пользователя в backend: $e');
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
