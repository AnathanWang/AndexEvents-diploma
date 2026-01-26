import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';

/// Сервис для работы с Supabase Authentication
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    print('🔵 [AuthService] Инициализирован');
    
    // Инициализируем GoogleSignIn с явным clientId для iOS
    _googleSignIn = GoogleSignIn(
      clientId: '672417054710-2gm36ur4k2nj5a7ed2re974mmq4qmt34.apps.googleusercontent.com',
      scopes: [
        'email',
        'profile',
      ],
    );
    print('🔵 [AuthService] GoogleSignIn инициализирован');
  }

  /// Получить текущего пользователя Supabase
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream для отслеживания изменений состояния авторизации
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Регистрация через Email и пароль
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    print('🔵 [AuthService] signUpWithEmail: "$email" (len=${email.length}), name: "$displayName"');
    try {
      // Создаём пользователя в Supabase
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
        emailRedirectTo: null, // Отключаем email редирект
      );

      print('🔵 [AuthService] Supabase response:');
      print('  - User: ${response.user?.id}');
      print('  - Session: ${response.session != null}');
      print('  - User confirmed: ${response.user?.emailConfirmedAt != null}');
      
      // Если требуется подтверждение email, выбрасываем специальную ошибку
      if (response.user != null && response.session == null) {
        throw Exception(
          'Для завершения регистрации необходимо подтвердить email. '
          'Проверьте почту и перейдите по ссылке из письма.'
        );
      }

      // Создаём пользователя в нашей базе данных
      if (response.user != null) {
        await _createUserInBackend(
          supabaseUid: response.user!.id,
          email: email,
          displayName: displayName,
          photoUrl: null,
        );
      }

      return response;
    } on AuthException catch (e) {
      throw _handleSupabaseAuthException(e);
    } catch (e) {
      throw Exception('Ошибка регистрации: $e');
    }
  }

  /// Вход через Email и пароль
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleSupabaseAuthException(e);
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }

  /// Вход через Google и получение статуса онбординга
  Future<Map<String, dynamic>> signInWithGoogleAndGetStatus() async {
    try {
      print('🔵 [Google Sign-In] Начинаем процесс входа...');
      
      // Запускаем процесс входа через Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In отменён пользователем');
      }

      // Получаем данные аутентификации
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Не удалось получить токены от Google');
      }

      // Входим в Supabase
      print('🔵 [Google Sign-In] Входим в Supabase...');
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      
      print('🔵 [Google Sign-In] Вход в Supabase успешен: ${response.user?.email}');

      if (response.user != null) {
        print('🔵 [Google Sign-In] Создаём/обновляем пользователя в backend...');
        await _createUserInBackend(
          supabaseUid: response.user!.id,
          email: response.user!.email!,
          displayName: response.user!.userMetadata?['full_name'] ?? googleUser.displayName ?? 'User',
          photoUrl: response.user!.userMetadata?['avatar_url'] ?? googleUser.photoUrl,
        );
      }

      // Получаем статус онбординга из backend
      bool isOnboardingCompleted = false;
      try {
        final profileData = await getCurrentUserProfile();
        isOnboardingCompleted = profileData['isOnboardingCompleted'] as bool? ?? false;
      } catch (e) {
        print('🟡 [Google Sign-In] Не удалось получить статус онбординга: $e');
        // Если не смогли получить профиль, считаем что онбординг не завершён
        isOnboardingCompleted = false;
      }

      return {
        'userCredential': response, // Возвращаем AuthResponse вместо UserCredential
        'isOnboardingCompleted': isOnboardingCompleted,
      };
    } on AuthException catch (e) {
      throw _handleSupabaseAuthException(e);
    } catch (e) {
      print('🔴 [Google Sign-In] Exception: $e');
      throw Exception('Ошибка входа через Google: $e');
    }
  }

  /// Выход из системы
  Future<void> signOut() async {
    await Future.wait([
      _supabase.auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Получить Supabase Access Token для API запросов
  Future<String?> getIdToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleSupabaseAuthException(e);
    }
  }

  /// Получить текущий профиль пользователя из бэкенда
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Пользователь не авторизован');
      }

      final token = session.accessToken;
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Не удалось загрузить профиль пользователя');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Если вы на физическом устройстве, задайте API_BASE_URL через --dart-define.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      throw Exception('Ошибка загрузки профиля: $e');
    }
  }

  /// Создание пользователя в нашей базе данных через backend API
  Future<void> _createUserInBackend({
    required String supabaseUid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'supabaseUid': supabaseUid,
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 201 && response.statusCode != 409) {
        throw Exception('Не удалось создать пользователя в базе данных (${response.statusCode})');
      }
    } catch (e) {
      print('🔴 [Backend] Ошибка создания пользователя в backend: $e');
    }
  }

  /// Обработка Supabase ошибок
  String _handleSupabaseAuthException(AuthException e) {
    // Маппинг распространённых ошибок Supabase на русский язык
    final message = e.message.toLowerCase();
    
    if (message.contains('invalid') && message.contains('email')) {
      return 'Некорректный формат email. Используйте формат: username@example.com';
    }
    if (message.contains('user already registered')) {
      return 'Пользователь с таким email уже зарегистрирован';
    }
    if (message.contains('invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (message.contains('email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту';
    }
    if (message.contains('password') && message.contains('short')) {
      return 'Пароль слишком короткий. Минимум 6 символов';
    }
    if (message.contains('weak password')) {
      return 'Слишком слабый пароль. Используйте буквы и цифры';
    }
    if (message.contains('rate limit')) {
      return 'Слишком много попыток. Попробуйте позже';
    }
    
    // Если не нашли подходящего сообщения, возвращаем оригинальное
    return 'Ошибка авторизации: ${e.message}';
  }
}
