import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_screen.dart';
import 'setup_profile_screen.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import '../../home/home_shell.dart';
import '../../../core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    LoggerService.debug('DEBUG: _handleLogin called, _isLoading: $_isLoading');
    
    if (_formKey.currentState?.validate() ?? false) {
      LoggerService.debug('DEBUG: Form validated, sending AuthLoginRequested');
      
      // Отправляем событие входа в AuthBloc
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    } else {
      LoggerService.debug('DEBUG: Form validation failed');
    }
  }

  void _navigateToRegister() {
    LoggerService.debug('🔵 [LoginScreen] Нажата кнопка регистрации');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          LoggerService.debug('🔵 [LoginScreen] Открываем RegisterScreen');
          return const RegisterScreen();
        },
      ),
    );
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
    // Сбрасываем _isLoading при каждой перестройке если не в состоянии AuthLoading
    final currentState = context.read<AuthBloc>().state;
    if (currentState is! AuthLoading && _isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
    
    return BlocListener<AuthBloc, AuthState>(
      listener: (BuildContext context, AuthState state) {
        LoggerService.debug('DEBUG: AuthState changed to: ${state.runtimeType}');
        
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthFailure) {
          CustomNotification.error(context, state.message);
        }
        
        // При успешной аутентификации навигация через andex_app.dart
        if (state is AuthAuthenticated) {
          LoggerService.debug('DEBUG: AuthAuthenticated received, навигация к ${state.isOnboardingCompleted ? "HomeShell" : "SetupProfileScreen"}');
          // Переходим к правильному экрану в зависимости от статуса onboarding
          Widget destination;
          if (!state.user.emailVerified) {
            destination = EmailVerificationScreen(userEmail: state.user.email ?? '');
          } else if (state.isOnboardingCompleted) {
            destination = const HomeShell();
          } else {
            destination = const SetupProfileScreen();
          }
          
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (context) => destination),
            (route) => false, // Удаляем все предыдущие routes
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
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
                              Icons.celebration_rounded,
                              size: 46,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'С возвращением',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F3552),
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Войдите, чтобы продолжить поиск событий и матчей',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5E6D86),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 26),
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
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _buildInputDecoration(
                                  label: 'Email',
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (String? value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите email';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                  );
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Введите корректный email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
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
                                      setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      );
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
                                  return null;
                                },
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Забыли пароль?',
                                    style: TextStyle(
                                      color: Color(0xFF4C61A8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
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
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                          'Войти',
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
                                label: const Text('Войти через Google'),
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
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              'Нет аккаунта? ',
                              style: TextStyle(color: Color(0xFF6D7997)),
                            ),
                            TextButton(
                              onPressed: _navigateToRegister,
                              child: const Text(
                                'Зарегистрироваться',
                                style: TextStyle(
                                  color: Color(0xFF1B62F6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // BlocListener
    );
  }
}
