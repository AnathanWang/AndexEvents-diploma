import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_glass_card.dart';
import '../widgets/auth_glass_scaffold.dart';
import '../widgets/auth_input_decoration.dart';

/// Экран восстановления пароля (TDD Phase: GREEN)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Некорректный email';
    }
    
    return null;
  }

  void _handlePasswordReset() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    context.read<AuthBloc>().add(AuthPasswordResetRequested(email: email));
  }

  @override
  Widget build(BuildContext context) {
    return AuthGlassScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F3552)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
                  if (state is AuthPasswordResetSuccess) {
                    setState(() => _isLoading = false);
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Письмо отправлено', style: TextStyle(color: Color(0xFF1F3552), fontWeight: FontWeight.bold)),
                        content: Text(
                          'На адрес ${_emailController.text} отправлено письмо '
                          'с инструкциями по восстановлению пароля.',
                          style: const TextStyle(color: Color(0xFF5E6D86)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context).pop(); // Return to login
                            },
                            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B62F6))),
                          ),
                        ],
                      ),
                    );
                  } else if (state is AuthFailure) {
                    setState(() => _isLoading = false);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: const Color(0xFFDE5A77),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else if (state is AuthLoading) {
                    setState(() => _isLoading = true);
                  }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
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
                                Icons.lock_reset_rounded,
                                size: 46,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Восстановление пароля',
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
                            'Введите email, который вы использовали при регистрации. Мы отправим вам письмо с инструкциями.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5E6D86),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),

                          AuthGlassCard(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const Key('forgotPassword_email_textField'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  validator: _validateEmail,
                                  decoration: authInputDecoration(
                                    label: 'Email',
                                    hint: 'example@mail.com',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
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
                                    key: const Key('forgotPassword_submit_button'),
                                    onPressed: _isLoading ? null : _handlePasswordReset,
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
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Отправить',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Вернуться к входу',
                              style: TextStyle(
                                color: Color(0xFF6D7997),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
          },
        ),
      ),
    );
  }
}
