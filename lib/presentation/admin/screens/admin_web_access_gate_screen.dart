import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/models/user_model.dart';
import '../../../data/services/user_service.dart';
import '../../auth/widgets/auth_glass_card.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';
import '../../auth/widgets/auth_input_decoration.dart';
import 'admin_dashboard_screen.dart';

class AdminWebAccessGateScreen extends StatefulWidget {
  const AdminWebAccessGateScreen({super.key});

  @override
  State<AdminWebAccessGateScreen> createState() =>
      _AdminWebAccessGateScreenState();
}

class _AdminWebAccessGateScreenState extends State<AdminWebAccessGateScreen> {
  final UserService _userService = UserService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isCheckingAccess = true;
  bool _isLoginInProgress = false;
  bool _isLogoutInProgress = false;
  String? _error;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _refreshAccess();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isAdminRole(String? role) {
    final normalized = role?.trim().toUpperCase();
    return normalized == 'ADMIN' || normalized == 'MODERATOR';
  }

  String _humanizeError(Object error) {
    final message = error.toString();
    if (message.contains('Unsupported operation')) {
      return 'Веб-конфигурация не поддерживается текущими настройками. Обновите страницу и повторите вход.';
    }
    if (message.contains('XMLHttpRequest') ||
        message.contains('ClientException') ||
        message.contains('Failed to fetch')) {
      return 'Не удалось обратиться к backend API. Проверьте, что Traefik/API доступны по http://localhost/api.';
    }
    if (message.contains('401') || message.contains('403')) {
      return 'Доступ запрещен. Убедитесь, что у пользователя роль ADMIN или MODERATOR.';
    }

    if (message.trim() == 'Error') {
      return 'Неизвестная web-ошибка. Откройте DevTools и проверьте Console/Network; чаще всего это CORS или блокировка API ключа Firebase.';
    }

    return message;
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Некорректный формат email.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Неверный email или пароль.';
      case 'user-disabled':
        return 'Пользователь заблокирован в Firebase Auth.';
      case 'operation-not-allowed':
        return 'Email/Password вход отключен в Firebase Authentication.';
      case 'network-request-failed':
        return 'Сетевая ошибка при входе. Проверьте интернет и доступ к Firebase.';
      case 'too-many-requests':
        return 'Слишком много попыток входа. Подождите и попробуйте снова.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'Web Firebase конфигурация некорректна (API key/app authorization).';
      case 'api-key-expired':
        return 'Firebase API key истек. Нужен новый web-ключ в firebase_options.dart или через FlutterFire CLI.';
      case 'unauthorized-domain':
        return 'Текущий домен не разрешен в Firebase Auth. Добавьте localhost в Authorized domains.';
      default:
        final msg = (e.message ?? '').trim();
        if (msg.isNotEmpty && msg != 'Error') {
          return '$msg (code: ${e.code})';
        }
        return 'Ошибка Firebase Auth (code: ${e.code}).';
    }
  }

  Future<void> _refreshAccess() async {
    setState(() {
      _isCheckingAccess = true;
      _error = null;
    });

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _isCheckingAccess = false;
        });
        return;
      }

      final user = await _userService.getCurrentUser();
      if (!mounted) return;

      if (!_isAdminRole(user.role)) {
        setState(() {
          _currentUser = null;
          _isCheckingAccess = false;
          _error = 'Недостаточно прав: роль ${user.role ?? 'UNKNOWN'}';
        });
        return;
      }

      setState(() {
        _currentUser = user;
        _isCheckingAccess = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _isCheckingAccess = false;
        _error = 'Ошибка проверки доступа: ${_humanizeError(e)}';
      });
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Введите email и пароль';
      });
      return;
    }

    setState(() {
      _isLoginInProgress = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _refreshAccess();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mapFirebaseAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка входа: ${_humanizeError(e)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoginInProgress = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLogoutInProgress = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _error = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLogoutInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const AuthGlassScaffold(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser != null) {
      final subtitle =
          '${_currentUser!.displayName ?? _currentUser!.email} • ${_currentUser!.role ?? 'UNKNOWN'}';
      return AdminDashboardScreen(
        showBackButton: false,
        onLogout: _logout,
        headerSubtitle: subtitle,
        userRole: _currentUser!.role ?? 'UNKNOWN',
      );
    }

    return AuthGlassScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AuthGlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF75878A), Color(0xFF7D6EEC)],
                        ),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'AndexEvents Admin Web',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF161823),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Доступ только для ролей ADMIN и MODERATOR',
                  style: TextStyle(
                    color: Color(0xFF6F789E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authInputDecoration(
                    label: 'Email',
                    hint: 'name@example.com',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: authInputDecoration(
                    label: 'Пароль',
                    hint: '••••••••',
                    icon: Icons.lock_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoginInProgress ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _isLoginInProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Войти в админку'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isCheckingAccess ||
                                _isLoginInProgress ||
                                _isLogoutInProgress)
                            ? null
                            : _refreshAccess,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Проверить доступ'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isCheckingAccess || _isLogoutInProgress)
                            ? null
                            : _logout,
                        icon: _isLogoutInProgress
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout, size: 18),
                        label: const Text('Выйти'),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB33853),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
