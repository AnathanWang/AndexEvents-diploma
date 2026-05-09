import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/andex_admin_web_app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AdminWebBootstrapApp());
}

class _AdminWebBootstrapApp extends StatefulWidget {
  const _AdminWebBootstrapApp();

  @override
  State<_AdminWebBootstrapApp> createState() => _AdminWebBootstrapAppState();
}

class _AdminWebBootstrapAppState extends State<_AdminWebBootstrapApp> {
  Object? _initError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initializeDateFormatting('ru', null);
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final String? appFontFamily = isApplePlatform ? '.SF Pro Text' : null;

    if (_ready) {
      return const AndexAdminWebApp();
    }

    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: appFontFamily,
          textTheme: ThemeData.light().textTheme.apply(fontFamily: appFontFamily),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 52,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Не удалось запустить Admin Web',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _initError.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF161823)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _initError = null;
                        });
                        _initialize();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: appFontFamily,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: appFontFamily),
      ),
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
