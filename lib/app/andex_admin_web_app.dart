import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../presentation/admin/screens/admin_web_access_gate_screen.dart';

class AndexAdminWebApp extends StatelessWidget {
  const AndexAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final String? appFontFamily = isApplePlatform ? '.SF Pro Text' : null;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5E60CE),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'AndexEvents Admin Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        fontFamily: appFontFamily,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: appFontFamily),
        scaffoldBackgroundColor: const Color(0xFFF6F7FF),
      ),
      home: const AdminWebAccessGateScreen(),
    );
  }
}
