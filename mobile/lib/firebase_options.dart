import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration read from `--dart-define`s, so no project secrets or
/// generated `flutterfire configure` output live in the repository.
///
/// ```sh
/// flutter run \
///   --dart-define=FIREBASE_PROJECT_ID=meeple-prod \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_ANDROID_APP_ID=1:...:android:... \
///   --dart-define=FIREBASE_IOS_APP_ID=1:...:ios:... \
///   --dart-define=FIREBASE_STORAGE_BUCKET=...   # optional
/// ```
///
/// When the values for the current platform are missing,
/// [DefaultFirebaseOptions.currentPlatform] is null and the app runs with push
/// notifications disabled.
abstract final class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.meeplehearth.meeple',
  );

  /// Options for the running platform, or null when Firebase is not
  /// configured for it.
  static FirebaseOptions? get currentPlatform =>
      forPlatform(kIsWeb ? null : defaultTargetPlatform);

  /// Visible for tests.
  static FirebaseOptions? forPlatform(
    TargetPlatform? platform, {
    String apiKey = _apiKey,
    String projectId = _projectId,
    String senderId = _senderId,
    String storageBucket = _storageBucket,
    String androidAppId = _androidAppId,
    String iosAppId = _iosAppId,
  }) {
    final appId = switch (platform) {
      TargetPlatform.android => androidAppId,
      TargetPlatform.iOS => iosAppId,
      _ => '',
    };
    if (apiKey.isEmpty || projectId.isEmpty || senderId.isEmpty || appId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: platform == TargetPlatform.iOS ? _iosBundleId : null,
    );
  }
}
