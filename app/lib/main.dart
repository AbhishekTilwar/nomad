import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/shell/status_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = AppConfig.firebaseOptions;
  if (options == null || AppConfig.releaseMissingApiUrl) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SetupRequiredScreen(),
      ),
    );
    return;
  }

  // Android/iOS may already have a native default app (google-services); reuse
  // it instead of throwing core/duplicate-app.
  try {
    await Firebase.initializeApp(options: options);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  if (AppConfig.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(AppConfig.emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(
      AppConfig.emulatorHost,
      AppConfig.firestoreEmulatorPort,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      AppConfig.emulatorHost,
      AppConfig.storageEmulatorPort,
    );
  }

  // Crash reporting only on real mobile builds.
  if (AppConfig.enableMobileOnlyServices) {
    // Crashlytics / App Check activation is added with platform configuration
    // (see docs/FIREBASE_SETUP.md); intentionally not faked here.
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error');
    return true;
  };

  runApp(
    NomadMingleApp(
      auth: FirebaseAuthRepository(),
      splashMinDuration: const Duration(milliseconds: 1800),
    ),
  );
}
