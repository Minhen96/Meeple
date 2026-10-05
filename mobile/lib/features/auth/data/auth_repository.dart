import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/features/auth/data/auth_local_storage.dart';
import 'package:meeple_hearth/features/auth/data/auth_remote_data_source.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(
      remote: ref.read(authRemoteDataSourceProvider),
      local: ref.read(authLocalStorageProvider),
    );

final class AuthRepository {
  const AuthRepository({
    required AuthRemoteDataSource remote,
    required AuthLocalStorage local,
  })  : _remote = remote,
        _local = local;

  final AuthRemoteDataSource _remote;
  final AuthLocalStorage _local;

  /// Returns the authenticated user, or null if not logged in.
  /// Falls back to a minimal stub if the network is unavailable.
  Future<User?> currentUser() async {
    final userId = await _local.getUserId();
    if (userId == null || await _local.getRefreshToken() == null) return null;

    try {
      return await _remote.getMe();
    } on UnauthorizedException {
      // The interceptor already tried a refresh; the session is gone.
      await _local.clearSession();
      return null;
    } on ApiException {
      // Offline or server trouble — stay signed in with a minimal stub.
      return User(
        id: userId,
        username: '',
        displayName: '',
        onboardingCompleted: true,
      );
    }
  }

  Future<User> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final result = await _remote.login(
      emailOrUsername: emailOrUsername,
      password: password,
    );
    await _local.saveSession(tokens: result.tokens, userId: result.user.id);
    return result.user;
  }

  /// Registers the account. The user must verify their email and then sign
  /// in; registration itself does not start a session.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) =>
      _remote.register(username: username, email: email, password: password);

  Future<User> verifyEmail({required String token}) async {
    final result = await _remote.verifyEmail(token: token);
    await _local.saveSession(tokens: result.tokens, userId: result.user.id);
    return result.user;
  }

  Future<User> googleLogin({required String idToken}) async {
    final result = await _remote.googleLogin(idToken: idToken);
    await _local.saveSession(tokens: result.tokens, userId: result.user.id);
    return result.user;
  }

  Future<User> reactivate({
    required String emailOrUsername,
    required String password,
  }) async {
    final result = await _remote.reactivate(
      emailOrUsername: emailOrUsername,
      password: password,
    );
    await _local.saveSession(tokens: result.tokens, userId: result.user.id);
    return result.user;
  }

  Future<void> resendVerification({required String email}) =>
      _remote.resendVerification(email: email);

  Future<void> logout() async {
    try {
      await _remote.logout(refreshToken: await _local.getRefreshToken());
    } on ApiException {
      // Best effort — the local session is cleared regardless.
    } finally {
      await _local.clearSession();
    }
  }

  /// Drops the local session only (e.g. after the account was deleted and
  /// the server already revoked every session).
  Future<void> clearLocalSession() => _local.clearSession();

  Future<void> forgotPassword({required String email}) =>
      _remote.forgotPassword(email: email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _remote.resetPassword(token: token, newPassword: newPassword);
}
