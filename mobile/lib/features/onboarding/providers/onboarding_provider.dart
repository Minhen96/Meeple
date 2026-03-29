import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  bool build() => false; // false = not submitting

  /// Update bio and location on the current user's profile.
  Future<void> updateProfile({
    String? bio,
    String? location,
  }) async {
    state = true;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch<Map<String, dynamic>>(
        ApiConstants.me,
        data: {
          if (bio != null) 'bio': bio,
          if (location != null) 'location': location,
        },
      );
      final updated = User.fromJson(res.data!);
      ref.read(authNotifierProvider.notifier).updateUser(updated);
    } catch (e) {
      throw ApiException.from(e);
    } finally {
      state = false;
    }
  }

  /// Trigger a BGG collection import for the given username.
  Future<void> importBgg(String bggUsername) async {
    state = true;
    try {
      final dio = ref.read(dioProvider);
      await dio.post<void>(
        ApiConstants.bgg,
        data: {'bggUsername': bggUsername},
      );
    } catch (e) {
      throw ApiException.from(e);
    } finally {
      state = false;
    }
  }

  /// Marks onboarding as complete and syncs the auth state.
  Future<void> completeOnboarding() async {
    state = true;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch<Map<String, dynamic>>(
        ApiConstants.me,
        data: {'onboardingCompleted': true},
      );
      final updated = User.fromJson(res.data!);
      ref.read(authNotifierProvider.notifier).updateUser(updated);
    } catch (e) {
      throw ApiException.from(e);
    } finally {
      state = false;
    }
  }
}
