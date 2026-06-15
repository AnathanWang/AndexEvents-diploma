import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'email_verification_screen.dart';
import '../widgets/auth_glass_card.dart';
import '../widgets/auth_glass_scaffold.dart';
import '../widgets/auth_input_decoration.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_acceptTerms) {
        CustomNotification.error(context, 'Примите условия использования');
        return;
      }

      context.read<AuthBloc>().add(
            AuthRegisterRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _nameController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (BuildContext context, AuthState state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthAuthenticated) {
          final email = state.user.email ?? _emailController.text.trim();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => EmailVerificationScreen(userEmail: email),
            ),
            (route) => false,
          );
          return;
        }

        if (state is AuthFailure) {
          CustomNotification.error(context, state.message);
        }
      },
      child: AuthGlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F3552)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        child: SafeArea(
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
                  AuthGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          key: const Key('register_name_textField'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: authInputDecoration(
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
                        TextFormField(
                          key: const Key('register_email_textField'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: authInputDecoration(
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
                              return 'Введите корректный email (например: user@example.com)';
                            }
                            final localPart = value.trim().split('@')[0];
                            if (localPart.length < 3) {
                              return 'Email должен содержать минимум 3 символа до @';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('register_password_textField'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: authInputDecoration(
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
                          decoration: authInputDecoration(
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
                            gradient: _isLoading
                                ? const LinearGradient(
                                    colors: <Color>[Color(0xFFB7C4DE), Color(0xFFA5B4CF)],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: <Color>[Color(0xFF0961F6), Color(0xFF2E8BFF)],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isLoading
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
                            onPressed: _isLoading ? null : _handleRegister,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
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
      ),
    );
  }
}
