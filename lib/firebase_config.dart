import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'importaciones-chato',
  );
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'importaciones-chato.firebasestorage.app',
  );

  static bool get _hasExplicitOptions {
    final appId = kIsWeb ? webAppId : androidAppId;
    return apiKey.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        appId.isNotEmpty &&
        projectId.isNotEmpty;
  }

  static bool get usesAndroidNativeOptions =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !_hasExplicitOptions;

  static bool get isConfigured {
    return _hasExplicitOptions || usesAndroidNativeOptions;
  }

  static Future<FirebaseApp> initializeApp() {
    if (usesAndroidNativeOptions) {
      return Firebase.initializeApp();
    }
    return Firebase.initializeApp(options: currentPlatformOptions);
  }

  static FirebaseOptions get currentPlatformOptions {
    if (!_hasExplicitOptions) {
      throw StateError('Firebase no está configurado para esta plataforma.');
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: kIsWeb ? webAppId : androidAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      authDomain: kIsWeb ? '$projectId.firebaseapp.com' : null,
    );
  }
}
