import 'package:meeple_hearth/features/auth/data/auth_local_storage.dart';
import 'package:meeple_hearth/features/auth/data/auth_remote_data_source.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
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
    if (userId == null) return null;

    try {
      return await _remote.getMe();
    } catch (_) {
      // Offline or token issue — treat as authenticated; interceptor handles 401.
      return User(
        id: userId,
        username: '',
        email: '',
        displayName: '',
        onboardingCompleted: true,
      );
    }
  }

  Future<User> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final response = await _remote.login(
      emailOrUsername: emailOrUsername,
      password: password,
    );
    await _local.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      userId: response.user.id,
    );
    return response.user;
  }

  Future<User> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _remote.register(
      username: username,
      email: email,
      password: password,
      displayName: displayName,
    );
    await _local.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      userId: response.user.id,
    );
    return response.user;
  }

  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _local.clearAll();
    }
  }

  Future<void> forgotPassword({required String email}) =>
      _remote.forgotPassword(email: email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _remote.resetPassword(token: token, newPassword: newPassword);
}
