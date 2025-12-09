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
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          print('🟢 [AndexApp] BlocBuilder state: ${authState.runtimeType}');
          
          // Генерируем уникальный ключ для MaterialApp на основе состояния
          final key = ValueKey('MaterialApp_${authState.runtimeType}_${authState is AuthAuthenticated ? authState.isOnboardingCompleted : "unknown"}');
          
          return MaterialApp(
            key: key,
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
            home: _buildHome(authState),
          );
        },
      ),
    );
  }

  Widget _buildHome(AuthState state) {
    if (state is AuthLoading || state is AuthInitial) {
      print('🟢 [AndexApp] Показываем загрузчик');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (state is AuthAuthenticated) {
      print('🟢 [AndexApp] AuthAuthenticated, isOnboardingCompleted: ${state.isOnboardingCompleted}');
      if (state.isOnboardingCompleted) {
        print('🟢 [AndexApp] Показываем HomeShell');
        return const HomeShell();
      }
      print('🟢 [AndexApp] Показываем SetupProfileScreen');
      return const SetupProfileScreen();
    }

    print('🟢 [AndexApp] Показываем OnboardingScreen');
    return const OnboardingScreen();
  }
}
