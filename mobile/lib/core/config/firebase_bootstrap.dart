import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:meeple_hearth/firebase_options.dart';

/// Whether Firebase was initialised at startup. Overridden in `main()`;
/// false (push disabled) everywhere else, including tests.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Initialises Firebase when it is configured for this platform.
///
/// Never throws: a missing or broken configuration only disables push.
Future<bool> initFirebase({FirebaseOptions? options}) async {
  final resolved = options ?? DefaultFirebaseOptions.currentPlatform;
  if (resolved == null) {
    AppLogger.info('Firebase not configured — push notifications disabled');
    return false;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: resolved);
    }
    return true;
  } catch (e, st) {
    AppLogger.error('Firebase initialisation failed', error: e, stackTrace: st);
    return false;
  }
}
