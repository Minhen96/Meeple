// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_summary.freezed.dart';
part 'user_summary.g.dart';

/// Friendship between the viewer and another user (GAP §6.1
/// `UserSummaryWithStatus.friendshipStatus`, lower-cased; the legacy
/// `friend-status` endpoint returns the upper-case form).
enum FriendshipStatus {
  none,
  pendingSent,
  pendingReceived,
  friends,
  blocked;

  static FriendshipStatus parse(Object? raw) =>
      switch (raw?.toString().toLowerCase()) {
        'pending_sent' => pendingSent,
        'pending_received' => pendingReceived,
        'friends' => friends,
        'blocked' => blocked,
        _ => none,
      };
}

/// The shared `UserSummary` shape `{id, username, displayName, avatarUrl,
/// deleted}`; also parses `UserProfileResponse`, `AuthorInfo`, `HostInfo`.
@freezed
class UserSummary with _$UserSummary {
  const factory UserSummary({
    required String id,
    @Default('') String username,
    @JsonKey(readValue: _readDisplayName) @Default('') String displayName,
    String? avatarUrl,
    @Default(false) bool deleted,
    @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
    @Default(FriendshipStatus.none)
    FriendshipStatus friendshipStatus,
  }) = _UserSummary;

  factory UserSummary.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryFromJson(json);
}

Object? _readDisplayName(Map<dynamic, dynamic> json, String key) {
  final name = json['displayName'];
  return name is String && name.isNotEmpty ? name : json['username'];
}

String _statusToJson(FriendshipStatus s) => switch (s) {
      FriendshipStatus.none => 'none',
      FriendshipStatus.pendingSent => 'pending_sent',
      FriendshipStatus.pendingReceived => 'pending_received',
      FriendshipStatus.friends => 'friends',
      FriendshipStatus.blocked => 'blocked',
    };
