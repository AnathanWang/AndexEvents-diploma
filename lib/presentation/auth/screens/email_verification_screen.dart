import 'dart:async';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../../widgets/common/custom_notification.dart';
import 'login_screen.dart';
import 'setup_profile_screen.dart';

/// Screen for email verification with resend functionality
class EmailVerificationScreen extends StatefulWidget {
  final String userEmail;
  final AuthService? authService;

  const EmailVerificationScreen({
    super.key,
    required this.userEmail,
    this.authService,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  late AuthService _authService;
  bool _isLoading = false;
  String? _message;
  bool _isError = false;
  bool _isCheckingVerification = false;
  
  late String _currentEmail;

  // Cooldown mechanism
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _pollingTimer;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 5; // 5 попыток по 3 секунды = 15 секунд автопроверки

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.userEmail;
    _authService = widget.authService ?? AuthService();
    WidgetsBinding.instance.addObserver(this);
    // Start polling for email verification every 3 seconds
    _startPolling();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check verification when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification();
    }
  }

  void _startPolling() {
    _pollingAttempts = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pollingAttempts >= _maxPollingAttempts) {
        timer.cancel();
        return;
      }
      _pollingAttempts++;
      if (!_isCheckingVerification) {
        _checkEmailVerification();
      }
    });
  }

  Future<void> _checkEmailVerification() async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
    });

    try {
      await _authService.reloadUser();
      final isVerified = _authService.isEmailVerified;

      if (isVerified && mounted) {
        // Email verified - navigate to profile setup
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const SetupProfileScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Ignore errors during background check
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  Future<void> _manualCheckVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });

    try {
      await _authService.reloadUser();
      final isVerified = _authService.isEmailVerified;

      if (isVerified) {
        if (mounted) {
          // Email verified - navigate to profile setup
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SetupProfileScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Email еще не подтвержден. Проверьте почту.';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Ошибка проверки статуса';
        _isError = true;
      });
    }
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldownSeconds > 0) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });

    try {
      await _authService.sendVerificationEmail();
      setState(() {
        _isLoading = false;
        _message = 'Письмо отправлено';
        _isError = false;
      });
      _startCooldown();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Ошибка при отправке письма: $e';
        _isError = true;
      });
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController(text: _currentEmail);
    bool isUpdating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Сменить email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Укажите правильный адрес электронной почты. На него будет отправлено новое письмо.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Новый Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isUpdating,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          final newEmail = emailController.text.trim();
                          if (newEmail.isEmpty || !newEmail.contains('@')) {
                            CustomNotification.show(context, 'Введите корректный email', isError: true);
                            return;
                          }

                          if (newEmail == _currentEmail) {
                            Navigator.pop(dialogContext);
                            return;
                          }

                          setDialogState(() => isUpdating = true);

                          try {
                            final user = _authService.currentUser;
                            if (user != null) {
                              // В последних версиях firebase_auth используется метод verifyBeforeUpdateEmail,
                              // который заодно отправляет письмо подтверждения на новый адрес
                              await user.verifyBeforeUpdateEmail(newEmail);
                              
                              if (mounted) {
                                setState(() {
                                  _currentEmail = newEmail;
                                  _message = 'Письмо отправлено на новый адрес';
                                  _isError = false;
                                });
                                _startCooldown();
                                Navigator.pop(dialogContext);
                                CustomNotification.show(context, 'Email успешно изменен');
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isUpdating = false);
                            final errorMsg = e.toString().contains('requires-recent-login') 
                                ? 'Требуется недавний вход. Выйдите и зарегистрируйтесь заново.'
                                : 'Ошибка смены email. Возможно адрес уже занят.';
                            CustomNotification.show(context, errorMsg, isError: true);
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFEAF2FF),
              Color(0xFFD9E8FF),
              Color(0xFFEFF5FF),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -110,
              right: -75,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F6CF8).withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -85,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8CB9FF).withValues(alpha: 0.16),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFF0961F6),
                              Color(0xFF4B94FF),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF0F6CF8).withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Подтверждение email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F3552),
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Мы отправили письмо с подтверждением на указанный адрес. Проверьте почту.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5E6D86),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0961F6),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF184B94).withValues(alpha: 0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_message != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isError
                                    ? const Color(0xFFDE5A77).withValues(alpha: 0.1)
                                    : const Color(0xFF34C759).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isError 
                                      ? const Color(0xFFDE5A77).withValues(alpha: 0.3)
                                      : const Color(0xFF34C759).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                                    color: _isError ? const Color(0xFFDE5A77) : const Color(0xFF34C759),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: TextStyle(
                                        color: _isError ? const Color(0xFFDE5A77) : const Color(0xFF2FA64D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  Color(0xFF0961F6),
                                  Color(0xFF2E8BFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF0A60F5).withValues(alpha: 0.34),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _manualCheckVerification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading && _isCheckingVerification
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Я подтвердил email',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          OutlinedButton.icon(
                            onPressed: _cooldownSeconds > 0 || _isLoading
                                ? null
                                : _resendVerificationEmail,
                            icon: const Icon(Icons.outgoing_mail),
                            label: _cooldownSeconds > 0
                                ? Text('Отправить повторно через $_cooldownSeconds сек')
                                : const Text('Отправить письмо повторно'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B2C4D),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: const BorderSide(color: Color(0xFFD7E2F7)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _showChangeEmailDialog,
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            label: const Text('Сменить email'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5E6D86),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: const BorderSide(color: Color(0xFFD7E2F7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(const AuthLogoutRequested());
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Выйти в меню входа',
                        style: TextStyle(
                          color: Color(0xFF6D7997),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
