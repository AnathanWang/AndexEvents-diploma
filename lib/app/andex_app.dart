import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/theme/app_colors.dart';
import '../core/services/logger_service.dart';
import '../data/services/auth_service.dart';
import '../presentation/auth/bloc/auth_bloc.dart';
import '../presentation/auth/bloc/auth_event.dart';
import '../presentation/auth/bloc/auth_state.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import '../presentation/home/home_shell.dart';
import '../presentation/auth/screens/setup_profile_screen.dart';
import '../presentation/auth/screens/email_verification_screen.dart';

class AndexApp extends StatelessWidget {
  const AndexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (BuildContext context) => AuthBloc(authService: AuthService())
        ..add(const AuthCheckRequested()),
      child: _buildMaterialApp(),
    );
  }

  Widget _buildMaterialApp() {
    final bool isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final String? appFontFamily = isApplePlatform ? '.SF Pro Text' : null;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      onSurface: AppColors.textPrimary,
    );

    return MaterialApp(
      title: 'Andex Events',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        primaryColor: AppColors.primary,
        fontFamily: appFontFamily,
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.surface,
        cardColor: AppColors.surface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return null;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary.withValues(alpha: 0.4);
            }
            return null;
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return null;
          }),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return null;
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ).apply(fontFamily: appFontFamily),
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
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          LoggerService.debug('🟢 [AndexApp] Auth state: ${authState.runtimeType}');
          return _buildHome(authState);
        },
      ),
    );
  }

  Widget _buildHome(AuthState state) {
    if (state is AuthLoading || state is AuthInitial) {
      LoggerService.debug('🟢 [AndexApp] Показываем загрузчик');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (state is AuthAuthenticated) {
      LoggerService.debug('🟢 [AndexApp] AuthAuthenticated, isOnboardingCompleted: ${state.isOnboardingCompleted}');
      if (!state.user.emailVerified) {
        LoggerService.debug('🟢 [AndexApp] Показываем EmailVerificationScreen (email не подтвержден)');
        return EmailVerificationScreen(userEmail: state.user.email ?? '');
      }
      if (state.isOnboardingCompleted) {
        LoggerService.debug('🟢 [AndexApp] Показываем HomeShell');
        return const HomeShell();
      }
      LoggerService.debug('🟢 [AndexApp] Показываем SetupProfileScreen');
      return const SetupProfileScreen();
    }

    LoggerService.debug('🟢 [AndexApp] Показываем OnboardingScreen');
    return const OnboardingScreen();
  }
}
