// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// A user profile.
///
/// Built from `AuthResponse` (login / verify-email / Google, which includes
/// [email]) or `UserProfileResponse` (`GET /users/me`, `/users/{id}`), incl.
/// the GAP §6.1 [WP5] additions. [displayName] falls back to the username.
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
    @Default(false) bool isVerified,

    /// `en` | `zh-CN`.
    String? preferredLanguage,
    String? timezone,
    DateTime? usernameChangeAvailableAt,

    /// Self only.
    String? bggUsername,
    @Default(false) bool deleted,
    DateTime? createdAt,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  UserSummary get summary => UserSummary(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        deleted: deleted,
      );
}

Object? _readDisplayName(Map<dynamic, dynamic> json, String key) {
  final name = json['displayName'];
  return name is String && name.isNotEmpty ? name : json['username'] ?? '';
}

/// `GET /auth/sessions` item (GAP §6.1 [WP5]).
@freezed
class ActiveSession with _$ActiveSession {
  const factory ActiveSession({
    required String id,
    String? deviceInfo,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    @Default(false) bool current,
  }) = _ActiveSession;

  factory ActiveSession.fromJson(Map<String, dynamic> json) =>
      _$ActiveSessionFromJson(json);
}
