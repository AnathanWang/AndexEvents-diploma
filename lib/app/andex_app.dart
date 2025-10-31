import 'package:flutter/material.dart';

import '../presentation/onboarding/onboarding_screen.dart';

class AndexApp extends StatelessWidget {
  const AndexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const OnboardingScreen(),
    );
  }
}
