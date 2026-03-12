import 'dart:async';
import 'package:andexevents/data/services/auth_service.dart';
import 'package:flutter/material.dart';

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

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late AuthService _authService;
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  // Cooldown mechanism
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
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
        child: Padding(
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
              const SizedBox(height: 16),

              // Back to login button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
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
