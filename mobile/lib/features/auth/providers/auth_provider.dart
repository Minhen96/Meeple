import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<User?> build() async {
    // A rejected refresh token ends the session: drop to logged-out so the
    // router sends the user to login.
    final sub = ref
        .read(authSessionManagerProvider)
        .sessionExpired
        .listen((_) => state = const AsyncValue.data(null));
    ref.onDispose(sub.cancel);

    return ref.read(authRepositoryProvider).currentUser();
  }

  /// Signs in. Errors are rethrown so the screen can react to specific codes
  /// (e.g. `EMAIL_NOT_VERIFIED`); the state stays logged-out on failure.
  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final user = await ref.read(authRepositoryProvider).login(
          emailOrUsername: emailOrUsername,
          password: password,
        );
    state = AsyncValue.data(user);
  }

  /// Creates the account; the user must verify their email before signing in.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) =>
      ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
          );

  /// Verifies the email with the token from the link and signs in.
  Future<void> verifyEmail(String token) async {
    final user =
        await ref.read(authRepositoryProvider).verifyEmail(token: token);
    state = AsyncValue.data(user);
  }

  Future<void> resendVerification(String email) =>
      ref.read(authRepositoryProvider).resendVerification(email: email);

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  /// Call after profile edits to sync the in-memory user object.
  /// Profile responses carry no email, so the known one is kept.
  void updateUser(User user) => state = AsyncValue.data(
        user.email != null
            ? user
            : user.copyWith(email: state.valueOrNull?.email),
      );
}
