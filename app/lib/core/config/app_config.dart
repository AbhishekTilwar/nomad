import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration. Values are supplied with `--dart-define` and are
/// NOT secret (Firebase web/mobile API keys identify the project; security comes
/// from Auth, rules and the backend). Never put service-account keys here.
class AppConfig {
  const AppConfig._();

  /// Use the local Firebase Emulator Suite (project `demo-nomadmingle`).
  static const useEmulator = bool.fromEnvironment('USE_EMULATOR');

  /// Host of the emulators. Android emulator needs `10.0.2.2`.
  static const emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  /// Optional web client id for Google Sign-In (iOS / server client id).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Resolves Firebase options from dart-defines. When using the emulator a
  /// dummy `demo-` project is used so no real project is required.
  /// Returns null when Firebase is not configured (the app then shows a
  /// setup screen instead of crashing).
  static FirebaseOptions? get firebaseOptions {
    if (useEmulator) {
      return FirebaseOptions(
        apiKey: _apiKey.isNotEmpty ? _apiKey : 'demo-api-key',
        appId: _appId.isNotEmpty ? _appId : '1:000000000000:web:demo',
        messagingSenderId: _senderId.isNotEmpty ? _senderId : '000000000000',
        projectId: _projectId.isNotEmpty ? _projectId : 'demo-nomadmingle',
        storageBucket: _storageBucket.isNotEmpty
            ? _storageBucket
            : 'demo-nomadmingle.appspot.com',
      );
    }
    if (_apiKey.isEmpty || _appId.isEmpty || _projectId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
    );
  }

  static bool get isConfigured => firebaseOptions != null;

  /// Crashlytics / App Check are unsupported on web or in emulator mode.
  static bool get enableMobileOnlyServices => !kIsWeb && !useEmulator;
}
