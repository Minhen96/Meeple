import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

// Storage key constants — never use raw strings outside this file.
const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kFcmToken = 'fcm_token';

@Riverpod(keepAlive: true)
SecureStorage secureStorage(SecureStorageRef ref) => SecureStorage();

/// Type-safe wrapper around [FlutterSecureStorage].
///
/// Uses encrypted shared preferences on Android and Keychain on iOS.
/// All reads/writes are async and return null on missing keys.
final class SecureStorage {
  SecureStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  final FlutterSecureStorage _storage;

  // ── Reads ──────────────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getFcmToken() => _storage.read(key: _kFcmToken);

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      if (userId != null) _storage.write(key: _kUserId, value: userId),
    ]);
  }

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _kFcmToken, value: token);

  // ── Deletion ───────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
