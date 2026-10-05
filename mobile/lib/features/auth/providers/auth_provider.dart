import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/analytics/analytics_service.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/data/google_auth_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

/// Work that must run while the session is still valid, right before logout
/// (e.g. unregistering the FCM token). Registered by long-lived services.
typedef BeforeLogoutHook = Future<void> Function();

final class LogoutHooks {
  final _hooks = <BeforeLogoutHook>[];

  /// Registers [hook]; returns a function that removes it again.
  void Function() add(BeforeLogoutHook hook) {
    _hooks.add(hook);
    return () => _hooks.remove(hook);
  }

  Future<void> runAll() async {
    for (final hook in List.of(_hooks)) {
      try {
        await hook();
      } catch (e) {
        AppLogger.warning('Before-logout hook failed', error: e);
      }
    }
  }
}

@Riverpod(keepAlive: true)
LogoutHooks logoutHooks(Ref ref) => LogoutHooks();

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

    final user = await ref.read(authRepositoryProvider).currentUser();
    if (user != null) await AnalyticsService.identify(user.id);
    return user;
  }

  /// Signs in. Errors are rethrown so the screen can react to specific codes
  /// (e.g. `EMAIL_NOT_VERIFIED`, `ACCOUNT_DELETED`); the state stays
  /// logged-out on failure.
  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final user = await ref.read(authRepositoryProvider).login(
          emailOrUsername: emailOrUsername,
          password: password,
        );
    await _signedIn(user);
  }

  /// Google sign-in: obtains an ID token and exchanges it at
  /// `POST /auth/google`. Returns false when the user cancelled. Throws
  /// `GOOGLE_EMAIL_NOT_VERIFIED` (401) / `GOOGLE_ACCOUNT_CONFLICT` (409).
  Future<bool> signInWithGoogle() async {
    final google = ref.read(googleAuthClientProvider);
    final idToken = await google.signIn();
    if (idToken == null) return false;
    try {
      final user =
          await ref.read(authRepositoryProvider).googleLogin(idToken: idToken);
      await _signedIn(user);
      return true;
    } catch (_) {
      // Let the user pick another Google account next time.
      await google.signOut();
      rethrow;
    }
  }

  /// Restores an account inside its 30-day deletion grace period.
  Future<void> reactivate({
    required String emailOrUsername,
    required String password,
  }) async {
    final user = await ref.read(authRepositoryProvider).reactivate(
          emailOrUsername: emailOrUsername,
          password: password,
        );
    await _signedIn(user);
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
    await _signedIn(user);
  }

  Future<void> resendVerification(String email) =>
      ref.read(authRepositoryProvider).resendVerification(email: email);

  Future<void> logout() async {
    await ref.read(logoutHooksProvider).runAll();
    await ref.read(authRepositoryProvider).logout();
    await _clearLocalData();
    state = const AsyncValue.data(null);
  }

  /// The account was deleted (soft): drop the local session without calling
  /// the backend, whose sessions are already revoked.
  Future<void> signOutLocally() async {
    await ref.read(authRepositoryProvider).clearLocalSession();
    await _clearLocalData();
    state = const AsyncValue.data(null);
  }

  /// Call after profile edits to sync the in-memory user object.
  /// Profile responses carry no email, so the known one is kept.
  void updateUser(User user) => state = AsyncValue.data(
        user.email != null
            ? user
            : user.copyWith(email: state.valueOrNull?.email),
      );

  Future<void> _signedIn(User user) async {
    state = AsyncValue.data(user);
    await AnalyticsService.identify(user.id);
  }

  Future<void> _clearLocalData() async {
    await ref.read(googleAuthClientProvider).signOut();
    await AnalyticsService.reset();
    try {
      await ref.read(cacheStoreProvider).clear();
    } catch (e) {
      AppLogger.warning('Clearing the offline cache failed', error: e);
    }
  }
}
