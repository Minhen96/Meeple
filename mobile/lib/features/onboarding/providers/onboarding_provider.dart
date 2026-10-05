import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  bool build() => false; // true while submitting

  /// Marks onboarding as complete (`PUT /users/me {onboardingCompleted}`)
  /// and syncs the auth state, which lets the router leave onboarding.
  Future<void> completeOnboarding() async {
    state = true;
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .updateMe(const ProfileUpdate(onboardingCompleted: true));
      ref.read(authNotifierProvider.notifier).updateUser(updated);
    } finally {
      state = false;
    }
  }
}
