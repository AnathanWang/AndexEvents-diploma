import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'email_verification_screen.dart';
import '../../../core/theme/app_colors.dart';

enum EmailAvailabilityStatus {
  initial,
  checking,
  available,
  taken,
  error,
}

class RegisterScreen extends StatefulWidget {
  final AuthService? authService; // For testing
  
  const RegisterScreen({super.key, this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  
  // Email availability check
  late final AuthService _authService;
  EmailAvailabilityStatus _emailStatus = EmailAvailabilityStatus.initial;
  Timer? _emailDebounce;
  String? _emailErrorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize AuthService (use provided one for testing or create new)
    _authService = widget.authService ?? AuthService();
    // Слушаем изменения email для проверки availability
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    // Cancel previous timer
    _emailDebounce?.cancel();
    
    final email = _emailController.text.trim();
    
    // Reset status if email is empty or invalid format
    if (email.isEmpty) {
      setState(() {
        _emailStatus = EmailAvailabilityStatus.initial;
        _emailErrorMessage = null;
      });
      return;
    }
    
    // Check email format before calling API
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _emailStatus = EmailAvailabilityStatus.initial;
      });
      return;
    }
    
    // Debounce - wait 500ms after user stops typing
    _emailDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkEmailAvailability(email);
    });
  }

  Future<void> _checkEmailAvailability(String email) async {
    setState(() {
      _emailStatus = EmailAvailabilityStatus.checking;
      _emailErrorMessage = null;
    });
    
    try {
      final isAvailable = await _authService.checkEmailAvailability(email);
      if (mounted) {
        setState(() {
          _emailStatus = isAvailable
              ? EmailAvailabilityStatus.available
              : EmailAvailabilityStatus.taken;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailStatus = EmailAvailabilityStatus.error;
          _emailErrorMessage = 'Ошибка проверки email';
        });
      }
    }
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_acceptTerms) {
        CustomNotification.error(context, 'Примите условия использования');
        return;
      }
      
      // Check email availability before proceeding
      if (_emailStatus == EmailAvailabilityStatus.taken) {
        CustomNotification.error(context, 'Email уже зарегистрирован');
        return;
      }
      
      if (_emailStatus == EmailAvailabilityStatus.checking) {
        CustomNotification.error(context, 'Дождитесь проверки email');
        return;
      }

      // Отправляем событие регистрации в AuthBloc
      context.read<AuthBloc>().add(
            AuthRegisterRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _nameController.text.trim(),
            ),
          );
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF5E74FF)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF4F8FF),
      labelStyle: const TextStyle(color: Color(0xFF5E688B)),
      hintStyle: const TextStyle(color: Color(0xFF9DA9C8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE6FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5E74FF), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDE5A77)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDE5A77), width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSubmitDisabled =
        _isLoading ||
        _emailStatus == EmailAvailabilityStatus.taken ||
        _emailStatus == EmailAvailabilityStatus.checking;

    return BlocListener<AuthBloc, AuthState>(
      listener: (BuildContext context, AuthState state) {
        if (state is AuthLoading) {
          // Показываем загрузку
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthAuthenticated) {
          // Регистрация успешна - переходим к проверке email
          LoggerService.warning('🟡 [RegisterScreen] AuthAuthenticated получен, переход к EmailVerificationScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (context) => EmailVerificationScreen(
                userEmail: _emailController.text.trim(),
              ),
            ),
            (route) => false, // Удаляем все предыдущие routes
          );
        } else if (state is AuthFailure) {
          // Показываем ошибку
          CustomNotification.error(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F3552)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFEAF2FF), Color(0xFFD9E8FF), Color(0xFFEFF5FF)],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -110,
                right: -80,
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F6CF8).withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -90,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Создать аккаунт',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F3552),
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Заполните данные, чтобы начать пользоваться приложением',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5E6D86),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                            children: <Widget>[
                              TextFormField(
                                key: const Key('register_name_textField'),
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _buildInputDecoration(
                                  label: 'Имя',
                                  hint: 'Иван Иванов',
                                  icon: Icons.person_outline,
                                ),
                                validator: (String? value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите имя';
                                  }
                                  if (value.length < 2) {
                                    return 'Имя должно быть минимум 2 символа';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  TextFormField(
                                    key: const Key('register_email_textField'),
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _buildInputDecoration(
                                      label: 'Email',
                                      hint: 'example@email.com',
                                      icon: Icons.email_outlined,
                                      suffixIcon: _buildEmailStatusIcon(),
                                    ),
                                    validator: (String? value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Введите email';
                                      }
                                      final emailRegex = RegExp(
                                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                      );
                                      if (!emailRegex.hasMatch(value.trim())) {
                                        return 'Введите корректный email (например: user@example.com)';
                                      }
                                      final localPart = value.trim().split('@')[0];
                                      if (localPart.length < 3) {
                                        return 'Email должен содержать минимум 3 символа до @';
                                      }
                                      return null;
                                    },
                                  ),
                                  _buildEmailStatusText(),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('register_password_textField'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _buildInputDecoration(
                                  label: 'Пароль',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите пароль';
                                  }
                                  if (value.length < 8) {
                                    return 'Пароль должен быть минимум 8 символов';
                                  }
                                  if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                                    return 'Пароль должен содержать буквы';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'Пароль должен содержать цифры';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('register_confirmPassword_textField'),
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: _buildInputDecoration(
                                  label: 'Подтвердите пароль',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                                      );
                                    },
                                  ),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Подтвердите пароль';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Пароли не совпадают';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F8FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDDE6FF)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Checkbox(
                                      value: _acceptTerms,
                                      onChanged: (bool? value) {
                                        setState(() => _acceptTerms = value ?? false);
                                      },
                                      activeColor: const Color(0xFF0961F6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6D7997),
                                            ),
                                            children: <TextSpan>[
                                              TextSpan(text: 'Я принимаю '),
                                              TextSpan(
                                                text: 'Условия использования',
                                                style: TextStyle(
                                                  color: Color(0xFF1B62F6),
                                                  decoration: TextDecoration.underline,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(text: ' и '),
                                              TextSpan(
                                                text: 'Политику конфиденциальности',
                                                style: TextStyle(
                                                  color: Color(0xFF1B62F6),
                                                  decoration: TextDecoration.underline,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: isSubmitDisabled
                                      ? const LinearGradient(
                                          colors: <Color>[Color(0xFFB7C4DE), Color(0xFFA5B4CF)],
                                        )
                                      : const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: <Color>[Color(0xFF0961F6), Color(0xFF2E8BFF)],
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isSubmitDisabled
                                      ? const <BoxShadow>[]
                                      : <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(0xFF0A60F5).withValues(alpha: 0.34),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                ),
                                child: ElevatedButton(
                                  key: const Key('register_button'),
                                  onPressed: isSubmitDisabled ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Зарегистрироваться',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Divider(color: Color(0xFFCCD8EF)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'или',
                                      style: TextStyle(color: Color(0xFF8A97B8)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Color(0xFFCCD8EF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        context.read<AuthBloc>().add(
                                          const AuthGoogleSignInRequested(),
                                        );
                                      },
                                icon: const Icon(Icons.g_mobiledata, size: 32),
                                label: const Text('Регистрация через Google'),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // Scaffold
    ); // BlocListener
  }

  // Иконка статуса проверки email
  Widget? _buildEmailStatusIcon() {
    switch (_emailStatus) {
      case EmailAvailabilityStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF75878A)),
            ),
          ),
        );
      case EmailAvailabilityStatus.available:
        return const Icon(Icons.check_circle, color: Colors.green);
      case EmailAvailabilityStatus.taken:
        return const Icon(Icons.error, color: Colors.red);
      case EmailAvailabilityStatus.error:
        return const Icon(Icons.warning, color: Colors.orange);
      case EmailAvailabilityStatus.initial:
        return null;
    }
  }

  // Текст статуса проверки email
  Widget _buildEmailStatusText() {
    if (_emailStatus == EmailAvailabilityStatus.initial) {
      return const SizedBox.shrink();
    }

    String text;
    Color color;

    switch (_emailStatus) {
      case EmailAvailabilityStatus.checking:
        text = 'Проверка доступности...';
        color = const Color(0xFF9E9E9E);
        break;
      case EmailAvailabilityStatus.available:
        text = '✅ Доступен';
        color = Colors.green;
        break;
      case EmailAvailabilityStatus.taken:
        text = '❌ Занят - используйте другой email';
        color = Colors.red;
        break;
      case EmailAvailabilityStatus.error:
        text = _emailErrorMessage ?? 'Ошибка проверки';
        color = Colors.orange;
        break;
      case EmailAvailabilityStatus.initial:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
