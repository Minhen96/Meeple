import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_local_storage.g.dart';

@Riverpod(keepAlive: true)
AuthLocalStorage authLocalStorage(AuthLocalStorageRef ref) =>
    AuthLocalStorage(ref.read(secureStorageProvider));

/// Auth-specific wrapper around [SecureStorage].
final class AuthLocalStorage {
  const AuthLocalStorage(this._storage);

  final SecureStorage _storage;

  Future<String?> getAccessToken() => _storage.getAccessToken();
  Future<String?> getRefreshToken() => _storage.getRefreshToken();
  Future<String?> getUserId() => _storage.getUserId();

  /// Persists the token pair and user id in one atomic write.
  Future<void> saveSession({
    required AuthTokens tokens,
    required String userId,
  }) =>
      _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: userId,
      );

  Future<void> clearSession() => _storage.clearSession();
}
