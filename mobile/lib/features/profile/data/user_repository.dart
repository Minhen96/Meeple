import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repository.g.dart';

@riverpod
UserRepository userRepository(Ref ref) =>
    UserRepository(ref.read(dioProvider));

/// Fields of `PUT /users/me` (only non-null ones are sent).
final class ProfileUpdate {
  const ProfileUpdate({
    this.displayName,
    this.username,
    this.bio,
    this.location,
    this.avatarUrl,
    this.preferredLanguage,
    this.timezone,
    this.onboardingCompleted,
  });

  final String? displayName;
  final String? username;
  final String? bio;
  final String? location;
  final String? avatarUrl;
  final String? preferredLanguage;
  final String? timezone;
  final bool? onboardingCompleted;

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        if (timezone != null) 'timezone': timezone,
        if (onboardingCompleted != null)
          'onboardingCompleted': onboardingCompleted,
      };
}

final class UserRepository {
  const UserRepository(this._dio);

  final Dio _dio;

  Future<User> getMe() => guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>(ApiConstants.me);
        return User.fromJson(res.data!);
      });

  /// `GET /users/{id}` — 404 when either side blocked the other.
  Future<User> getUser(String userId) => guardApi(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('${ApiConstants.users}/$userId');
        return User.fromJson(res.data!);
      });

  Future<User> updateMe(ProfileUpdate update) => guardApi(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          ApiConstants.me,
          data: update.toJson(),
        );
        return User.fromJson(res.data!);
      });

  /// `GET /users/{id}/stats`; zeros while the endpoint is missing.
  Future<UserStats> getStats(String userId) => guardApiOr(
        () async {
          final res = await _dio
              .get<Map<String, dynamic>>('${ApiConstants.users}/$userId/stats');
          return UserStats.fromJson(res.data ?? const {});
        },
        () async => const UserStats(),
      );
}
