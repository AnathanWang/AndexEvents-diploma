import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/andex_app.dart';
import 'firebase_options.dart';
import 'core/match/match_refresh_bus.dart';
import 'data/services/user_service.dart';
import 'core/services/logger_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  LoggerService.debug('Handling background message: ${message.messageId}');
}

Future<void> _syncFcmTokenIfAuthenticated(String? token) async {
  final normalized = token?.trim();
  if (normalized == null || normalized.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await UserService().updateFcmToken(normalized);
    LoggerService.info('[FCM] Token synced for user ${user.uid}');
  } catch (e) {
    LoggerService.warning('[FCM] Failed to sync token', e);
  }
}

Future<void> _fetchAndSyncFcmToken(
  FirebaseMessaging messaging, {
  required String reason,
}) async {
  for (int attempt = 1; attempt <= 6; attempt++) {
    try {
      final token = await messaging.getToken();
      final hasToken = token != null && token.trim().isNotEmpty;
      LoggerService.info(
        '[FCM] Token fetch ($reason) attempt $attempt/6: ${hasToken ? 'ok' : 'empty'}',
      );

      if (hasToken) {
        await _syncFcmTokenIfAuthenticated(token);
        return;
      }
    } catch (e) {
      LoggerService.warning(
        '[FCM] Token fetch ($reason) attempt $attempt failed',
        e,
      );
    }

    if (attempt < 6) {
      await Future.delayed(Duration(seconds: attempt));
    }
  }
}

Future<void> _configurePushNotifications() async {
  if (kIsWeb) {
    LoggerService.info('[FCM] Web push is not configured in this MVP flow');
    return;
  }

  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.setAutoInitEnabled(true);

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    LoggerService.info(
      '[FCM] Notification permission status: ${settings.authorizationStatus.name}',
    );

    await _fetchAndSyncFcmToken(messaging, reason: 'startup');

    messaging.onTokenRefresh.listen(
      (token) => _syncFcmTokenIfAuthenticated(token),
    );

    // Current user can still be null during app startup; sync again on auth changes.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      await _fetchAndSyncFcmToken(messaging, reason: 'auth-state-change');
    });

    FirebaseMessaging.onMessage.listen((message) {
      LoggerService.info(
        '[FCM] Foreground message received: ${message.messageId}',
      );
      final type = message.data['type']?.toString();
      if (type == 'incoming_like' ||
          type == 'incoming_super_like' ||
          type == 'mutual_match') {
        MatchRefreshBus.instance.notify();
      }
    });
  } catch (e) {
    LoggerService.warning('[FCM] Setup error', e);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for Russian locale
  await initializeDateFormatting('ru', null);
  
  // Initialize Supabase (Disabled - Moved to MinIO)
  // await Supabase.initialize(
  //   url: AppConfig.supabaseUrl,
  //   anonKey: AppConfig.supabaseAnonKey,
  // );
  
  // Initialize Firebase (uses android/app/google-services.json and ios/Runner/GoogleService-Info.plist)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (FirebaseAuth.instance.currentUser != null) {
    LoggerService.info(
      '[AuthStartup] Firebase user on launch: uid=${FirebaseAuth.instance.currentUser!.uid}',
    );
  }

  // Setup background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _configurePushNotifications();
  
  runApp(const AndexApp());
}
