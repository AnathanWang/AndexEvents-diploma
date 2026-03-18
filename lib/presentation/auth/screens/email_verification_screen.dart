import 'dart:async';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'setup_profile_screen.dart';

/// Screen for email verification with resend functionality
class EmailVerificationScreen extends StatefulWidget {
  final String userEmail;
  final AuthService? authService;

  const EmailVerificationScreen({
    Key? key,
    required this.userEmail,
    this.authService,
  }) : super(key: key);

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

  // Cooldown mechanism
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
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
        _message = 'Ошибка при отправке письма';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение email'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email icon
              Icon(
                Icons.email_outlined,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Проверьте почту',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Instructions
              const Text(
                'Мы отправили письмо с подтверждением на указанный адрес',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // User email
              Text(
                widget.userEmail,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Status message
              if (_message != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isError ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_message != null) const SizedBox(height: 16),

              // Resend button
              ElevatedButton(
                onPressed: _cooldownSeconds > 0 || _isLoading
                    ? null
                    : _resendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _cooldownSeconds > 0
                        ? Text('Отправить повторно через $_cooldownSeconds сек')
                        : const Text('Отправить письмо повторно'),
              ),
              const SizedBox(height: 8),

              // Manual check button
              OutlinedButton(
                onPressed: _isLoading ? null : _manualCheckVerification,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Я подтвердил email'),
              ),
              const SizedBox(height: 24),

              // Back to login button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Вернуться к входу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
