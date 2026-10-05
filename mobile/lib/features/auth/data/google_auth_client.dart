import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_auth_client.g.dart';

/// Obtains a Google ID token for `POST /auth/google` (fakeable in tests).
abstract interface class GoogleAuthClient {
  /// False when the client ids were not provided at build time; the
  /// "Continue with Google" button is then hidden.
  bool get isAvailable;

  /// The ID token, or null when the user cancelled.
  Future<String?> signIn();

  Future<void> signOut();
}

/// `google_sign_in` implementation. Needs `--dart-define`s
/// `GOOGLE_SERVER_CLIENT_ID` (the web client id the backend verifies the
/// token audience against) and, on iOS, `GOOGLE_IOS_CLIENT_ID` plus the
/// reversed id in ios/Flutter/GoogleSignIn.xcconfig.
final class PluginGoogleAuthClient implements GoogleAuthClient {
  PluginGoogleAuthClient({
    String serverClientId = AppConfig.googleServerClientId,
    String iosClientId = AppConfig.googleIosClientId,
  })  : _available = serverClientId.isNotEmpty &&
            (defaultTargetPlatform != TargetPlatform.iOS ||
                iosClientId.isNotEmpty),
        _google = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS &&
                  iosClientId.isNotEmpty
              ? iosClientId
              : null,
        );

  final bool _available;
  final GoogleSignIn _google;

  @override
  bool get isAvailable => _available;

  @override
  Future<String?> signIn() async {
    if (!_available) return null;
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  @override
  Future<void> signOut() async {
    if (!_available) return;
    try {
      await _google.signOut();
    } catch (_) {
      // Not signed in with Google on this device.
    }
  }
}

@Riverpod(keepAlive: true)
GoogleAuthClient googleAuthClient(Ref ref) => PluginGoogleAuthClient();
