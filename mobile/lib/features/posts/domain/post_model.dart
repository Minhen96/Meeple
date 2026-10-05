// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

/// A post (`PostResponse`, incl. the GAP §6.1 [WP3] additions `editedAt`,
/// `isBookmarked` and `author.deleted`). A null `author` (hard-deleted
/// account) parses as a deleted [UserSummary].
@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    @JsonKey(readValue: readUserOrDeleted) required UserSummary author,
    @JsonKey(defaultValue: '') required String caption,
    String? location,
    DateTime? playedAt,
    @Default(<String>[]) List<String> imageUrls,
    Game? game,
    @Default(<UserSummary>[]) List<UserSummary> taggedUsers,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(false) bool likedByMe,
    @Default(false) bool isBookmarked,
    String? eventId,
    DateTime? editedAt,
    required DateTime createdAt,
  }) = _Post;

  const Post._();

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  /// Posts can be edited for 48 hours (FEATURES §5.4).
  static const editWindow = Duration(hours: 48);

  bool canEdit({DateTime? now}) =>
      (now ?? DateTime.now()).difference(createdAt) < editWindow;
}

/// A post comment (`PostCommentResponse`:
/// `{id, authorId, authorUsername, authorDisplayName, authorAvatarUrl, body,
/// createdAt, editedAt}`).
///
/// Also accepts the nested `author` [UserSummary] and is null-safe for deleted
/// authors: `author.deleted`, a missing author id or the all-zero
/// placeholder id marks [authorDeleted] (names are then null).
@freezed
class Comment with _$Comment {
  const factory Comment({
    required String id,
    @JsonKey(readValue: _readAuthorId) @Default('') String authorId,
    @JsonKey(readValue: _readAuthorUsername) @Default('') String authorUsername,
    @JsonKey(readValue: _readAuthorDisplayName)
    @Default('')
    String authorDisplayName,
    @JsonKey(readValue: _readAuthorAvatar) String? authorAvatarUrl,
    @JsonKey(readValue: _readAuthorDeleted) @Default(false) bool authorDeleted,
    @JsonKey(name: 'body') required String content,
    DateTime? editedAt,
    required DateTime createdAt,
  }) = _Comment;

  const Comment._();

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);

  /// Comments can be edited for 24 hours (GAP §6.1 [WP3]).
  static const editWindow = Duration(hours: 24);

  bool canEdit({DateTime? now}) =>
      (now ?? DateTime.now()).difference(createdAt) < editWindow;

  /// The author as a [UserSummary] (for avatars and profile links).
  UserSummary get author => UserSummary(
        id: authorId,
        username: authorUsername,
        displayName:
            authorDisplayName.isNotEmpty ? authorDisplayName : authorUsername,
        avatarUrl: authorAvatarUrl,
        deleted: authorDeleted,
      );
}

Map<dynamic, dynamic>? _nestedAuthor(Map<dynamic, dynamic> json) {
  final author = json['author'];
  return author is Map ? author : null;
}

Object? _readAuthorId(Map<dynamic, dynamic> json, String key) =>
    json['authorId'] ?? _nestedAuthor(json)?['id'];

Object? _readAuthorUsername(Map<dynamic, dynamic> json, String key) =>
    json['authorUsername'] ?? _nestedAuthor(json)?['username'];

Object? _readAuthorDisplayName(Map<dynamic, dynamic> json, String key) =>
    json['authorDisplayName'] ?? _nestedAuthor(json)?['displayName'];

Object? _readAuthorAvatar(Map<dynamic, dynamic> json, String key) =>
    json['authorAvatarUrl'] ?? _nestedAuthor(json)?['avatarUrl'];

Object? _readAuthorDeleted(Map<dynamic, dynamic> json, String key) =>
    json['authorDeleted'] == true ||
    _nestedAuthor(json)?['deleted'] == true ||
    isDeletedUserId(_readAuthorId(json, key));
