// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

/// A post (`PostResponse`, incl. the GAP §6.1 [WP3] additions `editedAt`,
/// `isBookmarked` and `author.deleted`).
@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    required UserSummary author,
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

/// A post comment (`PostCommentResponse`).
@freezed
class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String authorId,
    @Default('') String authorUsername,
    String? authorAvatarUrl,
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
}
