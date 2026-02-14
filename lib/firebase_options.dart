// ┌──────────────────────────────────────────────────────────────┐
// │  FIREBASE OPTIONS — PLACEHOLDER                              │
// │                                                              │
// │  Replace this file by running:                               │
// │    flutterfire configure                                     │
// │                                                              │
// │  This will auto-generate proper values for your Firebase     │
// │  project across all platforms.                               │
// └──────────────────────────────────────────────────────────────┘

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not configured for this project.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ─── REPLACE these with your actual Firebase config ──────────
  // Run `flutterfire configure` to auto-generate real values.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAb2xKevyiOWYZhh0fQyxjtgiGsntr9GU4',
    appId: '1:1052407881927:android:38d9d3a76e0bf4eb87dee2',
    messagingSenderId: '1052407881927',
    projectId: 'vizo-app-8e1cf',
    storageBucket: 'vizo-app-8e1cf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDq_A0D4zhsX92SD4JSCtaqxor7u3391AE',
    appId: '1:1052407881927:ios:999051bc4175f5c687dee2',
    messagingSenderId: '1052407881927',
    projectId: 'vizo-app-8e1cf',
    storageBucket: 'vizo-app-8e1cf.firebasestorage.app',
    iosBundleId: 'com.vizo.vizo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDq_A0D4zhsX92SD4JSCtaqxor7u3391AE',
    appId: '1:1052407881927:ios:999051bc4175f5c687dee2',
    messagingSenderId: '1052407881927',
    projectId: 'vizo-app-8e1cf',
    storageBucket: 'vizo-app-8e1cf.firebasestorage.app',
    iosBundleId: 'com.vizo.vizo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR-WINDOWS-API-KEY',
    appId: '1:000000000000:windows:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'vizo-app',
    storageBucket: 'vizo-app.appspot.com',
  );
}