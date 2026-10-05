// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// The signed-in user.
///
/// Built from `AuthResponse` (login / verify-email / Google, which includes
/// [email]) or `UserProfileResponse` (`GET /users/me`, which does not).
/// [displayName] falls back to the username.
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String username,
    String? email,
    @JsonKey(readValue: _readDisplayName) required String displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    @Default(false) bool onboardingCompleted,
    @Default(false) bool isAdmin,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

Object? _readDisplayName(Map<dynamic, dynamic> json, String key) =>
    json['displayName'] ?? json['username'] ?? '';
