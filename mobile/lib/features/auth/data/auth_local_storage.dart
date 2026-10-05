import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_local_storage.g.dart';

@Riverpod(keepAlive: true)
AuthLocalStorage authLocalStorage(AuthLocalStorageRef ref) => AuthLocalStorage(
      ref.read(secureStorageProvider),
      ref.read(authSessionManagerProvider),
    );

/// Auth-specific wrapper around [SecureStorage].
///
/// Session writes go through [AuthSessionManager] so that signing in or out
/// invalidates any token refresh still in flight for the previous session.
final class AuthLocalStorage {
  const AuthLocalStorage(this._storage, this._session);

  final SecureStorage _storage;
  final AuthSessionManager _session;

  Future<String?> getAccessToken() => _storage.getAccessToken();
  Future<String?> getRefreshToken() => _storage.getRefreshToken();
  Future<String?> getUserId() => _storage.getUserId();

  /// Persists the token pair and user id in one atomic write.
  Future<void> saveSession({
    required AuthTokens tokens,
    required String userId,
  }) =>
      _session.saveTokens(tokens, userId: userId);

  Future<void> clearSession() => _session.clear();
}
