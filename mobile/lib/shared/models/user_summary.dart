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
/// deleted}`; also parses `UserProfileResponse`, `AuthorInfo`, `HostInfo`,
/// `SuggestedUser` and `UserSummaryWithStatus`.
///
/// Null-safe for deleted accounts: a soft-deleted user arrives as
/// `{id, deleted: true}` with null names; a hard-deleted one carries the
/// all-zero [deletedUserId] placeholder (or no `id` at all) — both parse with
/// [deleted] set.
@freezed
class UserSummary with _$UserSummary {
  const factory UserSummary({
    @JsonKey(defaultValue: '') required String id,
    @Default('') String username,
    @JsonKey(readValue: _readDisplayName) @Default('') String displayName,
    String? avatarUrl,
    @JsonKey(readValue: _readDeleted) @Default(false) bool deleted,
    @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
    @Default(FriendshipStatus.none)
    FriendshipStatus friendshipStatus,
  }) = _UserSummary;

  factory UserSummary.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryFromJson(json);
}

/// Reads a nested user object, substituting a deleted placeholder when the
/// server sent `null` (the account was hard-deleted).
Object? readUserOrDeleted(Map<dynamic, dynamic> json, String key) =>
    json[key] ?? const <String, dynamic>{'deleted': true};

/// The id the backend puts on placeholders for hard-deleted accounts.
const deletedUserId = '00000000-0000-0000-0000-000000000000';

/// Whether [id] cannot name a live account (missing or the placeholder).
bool isDeletedUserId(Object? id) =>
    id == null || id == '' || id == deletedUserId;

Object? _readDeleted(Map<dynamic, dynamic> json, String key) =>
    json['deleted'] == true || isDeletedUserId(json['id']);

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
