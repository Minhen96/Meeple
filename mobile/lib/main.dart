import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/storage/isar_service.dart';
import 'package:meeple_hearth/firebase_options.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:meeple_hearth/app.dart';

/// Background FCM handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background message received — OS notification tray handles display.
  // No UI operations permitted here.
}

Future<void> main() async {
  await runZonedGuarded(
    _bootstrap,
    (error, stack) => Sentry.captureException(error, stackTrace: stack),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar with dark icons (warm off-white background).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Enable edge-to-edge rendering on Android 15+.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase — must be initialised before registering the background handler.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Isar local database.
  await IsarService.instance.initialize();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  const environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      // ignore: inference_failure_on_untyped_parameter
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = environment == 'production' ? 0.2 : 1.0;
        options.environment = environment;
        options.attachScreenshot = true;
      },
      appRunner: _runApp,
    );
  } else {
    await _runApp();
  }
}

Future<void> _runApp() async {
  runApp(
    const ProviderScope(
      child: MeepleApp(),
    ),
  );
}
