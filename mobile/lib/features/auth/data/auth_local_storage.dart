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

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) =>
      _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
      );

  Future<void> clearAll() => _storage.clearAll();
}
