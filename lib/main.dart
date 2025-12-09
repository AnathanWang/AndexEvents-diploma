import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/andex_app.dart';
// import 'core/config/firebase_config.dart';
import 'core/config/app_config.dart';

// Background message handler
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
//   print('Handling background message: ${message.messageId}');
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for Russian locale
  await initializeDateFormatting('ru', null);
  
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  // Initialize Firebase (Removed)
  // await Firebase.initializeApp(
  //   options: FirebaseConfig.currentPlatform,
  // );

  // Setup background messaging handler
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  // try {
  //   final messaging = FirebaseMessaging.instance;
  //   await messaging.requestPermission(
  //     alert: true,
  //     badge: true,
  //     sound: true,
  //     provisional: false,
  //   );

  //   // Get FCM token (может не работать на симуляторе iOS)
  //   try {
  //     final fcmToken = await messaging.getToken();
  //     print('FCM Token: $fcmToken');
  //   } catch (e) {
  //     print('FCM token not available: $e');
  //   }
  // } catch (e) {
  //   print('Firebase Messaging setup error: $e');
  // }
  
  runApp(const AndexApp());
}
