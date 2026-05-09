import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

import '../presentation/admin/screens/admin_web_access_gate_screen.dart';

class AndexAdminWebApp extends StatelessWidget {
  const AndexAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      title: 'AndexEvents Admin Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        primaryColor: AppColors.primary,
        fontFamily: appFontFamily,
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
        textTheme: ThemeData.light().textTheme.apply(fontFamily: appFontFamily),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const AdminWebAccessGateScreen(),
    );
  }
}
