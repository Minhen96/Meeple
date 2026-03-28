import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<User?> build() async {
    return ref.read(authRepositoryProvider).currentUser();
  }

  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(
            emailOrUsername: emailOrUsername,
            password: password,
          ),
    );
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
            displayName: displayName,
          ),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  /// Call after profile edits to sync the in-memory user object.
  void updateUser(User user) => state = AsyncValue.data(user);
}
