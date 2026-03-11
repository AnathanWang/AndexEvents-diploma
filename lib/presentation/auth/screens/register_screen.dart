import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'setup_profile_screen.dart';

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

  void _skipDetailedSetup() {
    // Пропускаем регистрацию и переходим сразу на детальную настройку профиля
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SetupProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (BuildContext context, AuthState state) {
        if (state is AuthLoading) {
          // Показываем загрузку
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthAuthenticated) {
          // Регистрация успешна - переходим к настройке профиля
          LoggerService.warning('🟡 [RegisterScreen] AuthAuthenticated получен, переход к SetupProfileScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (context) => const SetupProfileScreen(),
            ),
            (route) => false, // Удаляем все предыдущие routes
          );
        } else if (state is AuthFailure) {
          // Показываем ошибку
          CustomNotification.error(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4A4D6A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Заголовок
                const Text(
                  'Создать аккаунт',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A4D6A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Заполните данные для регистрации',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Имя
                TextFormField(
                  key: const Key('register_name_textField'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    hintText: 'Иван Иванов',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                    ),
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
                const SizedBox(height: 16),
                
                // Email
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const Key('register_email_textField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: _buildEmailStatusIcon(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                        ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите email';
                        }
                        // Более строгая валидация email
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Введите корректный email (например: user@example.com)';
                        }
                        // Проверка минимальной длины локальной части (до @)
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
                const SizedBox(height: 16),
                
                // Пароль
                TextFormField(
                  key: const Key('register_password_textField'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
                    ),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите пароль';
                    }
                    if (value.length < 8) {
                      return 'Пароль должен быть минимум 8 символов';
                    }
                    // Проверка на сложность: минимум одна буква и одна цифра
                    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                      return 'Пароль должен содержать буквы';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(value)) {
                      return 'Пароль должен содержать цифры';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Подтверждение пароля
                TextFormField(
                  key: const Key('register_confirmPassword_textField'),
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF5E60CE), width: 2),
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
                const SizedBox(height: 24),
                
                // Чекбокс условий
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (bool? value) {
                        setState(() => _acceptTerms = value ?? false);
                      },
                      activeColor: const Color(0xFF5E60CE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                            children: <TextSpan>[
                              const TextSpan(text: 'Я принимаю '),
                              TextSpan(
                                text: 'Условия использования',
                                style: const TextStyle(
                                  color: Color(0xFF5E60CE),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' и '),
                              TextSpan(
                                text: 'Политику конфиденциальности',
                                style: const TextStyle(
                                  color: Color(0xFF5E60CE),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Кнопка "Пропустить регистрацию"
                TextButton(
                  onPressed: _skipDetailedSetup,
                  child: const Text(
                    'Пропустить регистрацию',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Кнопка регистрации
                ElevatedButton(
                  key: const Key('register_button'),
                  onPressed: (_isLoading || _emailStatus == EmailAvailabilityStatus.taken || _emailStatus == EmailAvailabilityStatus.checking) 
                      ? null 
                      : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E60CE),
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
                          'Зарегистрироваться',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                
                // Разделитель
                Row(
                  children: const <Widget>[
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'или',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Социальные сети
                OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
                        },
                  icon: const Icon(Icons.g_mobiledata, size: 32),
                  label: const Text('Регистрация через Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A4D6A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),

              ],
            ),
          ),
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E60CE)),
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
