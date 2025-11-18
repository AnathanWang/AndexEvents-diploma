import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBb0dFBcPNdRoC9Q-h2yaxHgZvWbyIVqmg',
    appId: '1:672417054710:android:b8d5ec206f9e8bd3ded1d7',
    messagingSenderId: '672417054710',
    projectId: 'andexevents',
    storageBucket: 'andexevents.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA2dxERL5q8KoSA3_9_iztImlu97Wktg6I',
    appId: '1:672417054710:ios:1918ac2d197286a4ded1d7',
    messagingSenderId: '672417054710',
    projectId: 'andexevents',
    storageBucket: 'andexevents.firebasestorage.app',
    iosBundleId: 'com.anathanwang.andexevents',
  );

  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) {
      return ios;
    } else if (Platform.isAndroid) {
      return android;
    } else {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      );
    }
  }
}
