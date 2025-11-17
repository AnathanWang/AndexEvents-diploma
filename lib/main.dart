import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/andex_app.dart';
// import 'core/config/firebase_config.dart';

// TODO: Настроить Firebase позже
// Background message handler
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print('Handling background message: ${message.messageId}');
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Раскомментируйте когда настроите Firebase
  // Initialize Firebase
  // await Firebase.initializeApp(
  //   options: FirebaseConfig.currentPlatform,
  // );

  // Setup background messaging handler
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  // final messaging = FirebaseMessaging.instance;
  // await messaging.requestPermission(
  //   alert: true,
  //   badge: true,
  //   sound: true,
  //   provisional: false,
  // );

  // Get FCM token
  // final fcmToken = await messaging.getToken();
  // print('FCM Token: $fcmToken');
  
  runApp(const AndexApp());
}
