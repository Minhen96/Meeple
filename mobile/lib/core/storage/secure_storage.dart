import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

// Storage key constants — never use raw strings outside this file.
//
// Access token, refresh token and user id live together in ONE entry so a
// token rotation is persisted atomically: a crash between two separate writes
// could otherwise leave a stale (already rotated) refresh token on disk, and
// presenting a rotated refresh token later makes the backend revoke every
// session of the user.
const _kSession = 'auth_session';
const _kFcmToken = 'fcm_token';

// Pre-blob keys, read once for migration and then removed.
const _kLegacyAccessToken = 'access_token';
const _kLegacyRefreshToken = 'refresh_token';
const _kLegacyUserId = 'user_id';

@Riverpod(keepAlive: true)
SecureStorage secureStorage(SecureStorageRef ref) => SecureStorage();

/// The persisted auth session.
final class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String? userId;
}

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

  Future<StoredSession?> getSession() async {
    final raw = await _storage.read(key: _kSession);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final access = map['accessToken'] as String?;
        final refresh = map['refreshToken'] as String?;
        if (access != null && refresh != null) {
          return StoredSession(
            accessToken: access,
            refreshToken: refresh,
            userId: map['userId'] as String?,
          );
        }
      } on FormatException {
        // Corrupt entry — treat as logged out.
      }
      return null;
    }
    return _migrateLegacySession();
  }

  Future<String?> getAccessToken() async => (await getSession())?.accessToken;
  Future<String?> getRefreshToken() async => (await getSession())?.refreshToken;
  Future<String?> getUserId() async => (await getSession())?.userId;
  Future<String?> getFcmToken() => _storage.read(key: _kFcmToken);

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Persists the whole session in a single write. When [userId] is omitted
  /// the previously stored user id is kept.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? (await getSession())?.userId;
    await _writeSession(accessToken, refreshToken, effectiveUserId);
  }

  Future<void> _writeSession(
    String accessToken,
    String refreshToken,
    String? userId,
  ) =>
      _storage.write(
        key: _kSession,
        value: jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          if (userId != null) 'userId': userId,
        }),
      );

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _kFcmToken, value: token);

  // ── Deletion ───────────────────────────────────────────────────────────────

  /// Removes the auth session (tokens + user id) but keeps device data such as
  /// the FCM token.
  Future<void> clearSession() async {
    await _storage.delete(key: _kSession);
    await _deleteLegacyKeys();
  }

  Future<void> clearAll() => _storage.deleteAll();

  // ── Migration ──────────────────────────────────────────────────────────────

  Future<StoredSession?> _migrateLegacySession() async {
    final access = await _storage.read(key: _kLegacyAccessToken);
    final refresh = await _storage.read(key: _kLegacyRefreshToken);
    final userId = await _storage.read(key: _kLegacyUserId);
    if (access == null || refresh == null) return null;
    await _writeSession(access, refresh, userId);
    await _deleteLegacyKeys();
    return StoredSession(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
  }

  Future<void> _deleteLegacyKeys() async {
    await _storage.delete(key: _kLegacyAccessToken);
    await _storage.delete(key: _kLegacyRefreshToken);
    await _storage.delete(key: _kLegacyUserId);
  }
}
