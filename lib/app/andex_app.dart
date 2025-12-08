import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/services/auth_service.dart';
import '../presentation/auth/bloc/auth_bloc.dart';
import '../presentation/auth/bloc/auth_event.dart';
import '../presentation/auth/bloc/auth_state.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import '../presentation/home/home_shell.dart';
import '../presentation/auth/screens/setup_profile_screen.dart';

class AndexApp extends StatelessWidget {
  const AndexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (BuildContext context) => AuthBloc(authService: AuthService())
        ..add(const AuthCheckRequested()),
      child: MaterialApp(
      title: 'Andex Events',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E60CE),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A4D6A)),
        ),
        useMaterial3: true,
      ),
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (BuildContext context, AuthState state) {
          if (state is AuthLoading || state is AuthInitial) {
            // Показываем загрузчик пока проверяем авторизацию
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Если пользователь авторизован и завершил онбординг - показываем главный экран
            if (state.isOnboardingCompleted) {
              return const HomeShell();
            }
            // Если онбординг не завершён - показываем экран настройки профиля
            return const SetupProfileScreen();
          }

          // Если не авторизован - показываем онбординг
          return const OnboardingScreen();
        },
      ),
      ),
    );
  }
}
