// Firebase config for project: supplymapper (linked from web app).
// To regenerate with FlutterFire CLI: flutterfire configure --project=supplymapper

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCshZiCFX7djYdP5GZ6g0P7qaz4Lt7OvVE',
    appId: '1:1053711084660:web:62622b2b429cb76658b521',
    messagingSenderId: '1053711084660',
    projectId: 'supplymapper',
    authDomain: 'supplymapper.firebaseapp.com',
    storageBucket: 'supplymapper.firebasestorage.app',
  );

  // TODO: Run `flutterfire configure` to generate real Android appId.
  // For now the web config is reused so Firebase.initializeApp won't crash.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCshZiCFX7djYdP5GZ6g0P7qaz4Lt7OvVE',
    appId: '1:1053711084660:web:62622b2b429cb76658b521',
    messagingSenderId: '1053711084660',
    projectId: 'supplymapper',
    storageBucket: 'supplymapper.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCshZiCFX7djYdP5GZ6g0P7qaz4Lt7OvVE',
    appId: '1:1053711084660:ios:placeholder',
    messagingSenderId: '1053711084660',
    projectId: 'supplymapper',
    storageBucket: 'supplymapper.firebasestorage.app',
    iosBundleId: 'com.findr.findrFlutter',
  );

  /// macOS uses the same config as iOS (same bundle ID style).
  static FirebaseOptions get macos => ios;
}
