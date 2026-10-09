import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/shell/status_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = AppConfig.firebaseOptions;
  if (options == null) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SetupRequiredScreen(),
      ),
    );
    return;
  }

  await Firebase.initializeApp(options: options);
  if (AppConfig.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(AppConfig.emulatorHost, 9099);
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

  runApp(NomadMingleApp(auth: FirebaseAuthRepository()));
}
