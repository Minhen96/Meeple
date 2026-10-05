import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/app.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/config/firebase_bootstrap.dart';
import 'package:meeple_hearth/core/storage/isar_service.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Background FCM handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initFirebase();
  // The OS shows the notification itself; no UI work is allowed here.
}

Future<void> main() async {
  await runZonedGuarded(
    _bootstrap,
    (error, stack) => Sentry.captureException(error, stackTrace: stack),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase is optional: without --dart-define FIREBASE_* the app runs with
  // push disabled instead of crashing.
  final firebaseReady = await initFirebase();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // The offline cache is optional too: reads fall back to the network.
  try {
    await IsarService.instance.initialize();
  } catch (e) {
    AppLogger.warning('Offline cache unavailable', error: e);
  }

  final app = ProviderScope(
    overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
    child: const MeepleApp(),
  );

  if (AppConfig.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate =
            AppConfig.environment == 'production' ? 0.2 : 1.0;
        options.environment = AppConfig.environment;
        options.sendDefaultPii = false;
      },
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}
