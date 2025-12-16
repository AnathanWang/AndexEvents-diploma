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

          final colorScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF5E60CE),
            brightness: Brightness.light,
          );
          
          return MaterialApp(
            key: key,
            title: 'Andex Events',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: colorScheme,
              scaffoldBackgroundColor: const Color(0xFFF5F6FA),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A4D6A)),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: colorScheme.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.error, width: 1.5),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                insetPadding: const EdgeInsets.all(16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentTextStyle: TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: colorScheme.inverseSurface,
                actionTextColor: colorScheme.primary,
                showCloseIcon: true,
                closeIconColor: colorScheme.onInverseSurface,
              ),
              popupMenuTheme: PopupMenuThemeData(
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                titleTextStyle: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                contentTextStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
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
