import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'andex-events',
    storageBucket: 'andex-events.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:ios:YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'andex-events',
    iosBundleId: 'com.andex.events',
    storageBucket: 'andex-events.appspot.com',
  );

  static FirebaseOptions get currentPlatform {
    // ignore: dead_code
    if (const bool.fromEnvironment('dart.library.io')) {
      // Running on mobile or desktop
      return android; // Change based on your needs
    } else {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      );
    }
  }
}
