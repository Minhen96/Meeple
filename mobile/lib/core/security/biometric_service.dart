import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:local_auth/local_auth.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_service.g.dart';

/// Device authentication used by the optional biometric app lock
/// (docs/MOBILE_FLUTTER.md §12). Fakeable in tests.
abstract interface class DeviceAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

final class LocalAuthAuthenticator implements DeviceAuthenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.canCheckBiometrics ||
              (await _auth.getAvailableBiometrics()).isNotEmpty);
    } catch (e) {
      AppLogger.warning('Biometric availability check failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Device PIN is allowed as a fallback.
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      AppLogger.warning('Biometric authentication failed', error: e);
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
DeviceAuthenticator deviceAuthenticator(Ref ref) => LocalAuthAuthenticator();

/// Whether the biometric app lock is switched on (stored on the device).
@Riverpod(keepAlive: true)
class BiometricLock extends _$BiometricLock {
  static const _prefKey = 'biometric_enabled';

  @override
  Future<bool> build() async {
    try {
      return await ref.read(secureStorageProvider).readPref(_prefKey) ==
          'true';
    } catch (_) {
      return false;
    }
  }

  /// Enabling requires a successful authentication first. Returns false
  /// when unavailable or the user cancelled.
  Future<bool> setEnabled({required bool enabled, required String reason}) async {
    final storage = ref.read(secureStorageProvider);
    if (!enabled) {
      await storage.deletePref(_prefKey);
      state = const AsyncValue.data(false);
      return true;
    }
    final auth = ref.read(deviceAuthenticatorProvider);
    if (!await auth.isAvailable()) return false;
    if (!await auth.authenticate(reason)) return false;
    await storage.writePref(_prefKey, 'true');
    state = const AsyncValue.data(true);
    return true;
  }
}
