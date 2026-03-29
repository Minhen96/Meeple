import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    required String authorId,
    required String authorUsername,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    @Default([]) List<String> imageUrls,
    String? taggedGameId,
    String? taggedGameName,
    String? linkedEventId,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(false) bool isLikedByMe,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}

@freezed
class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String postId,
    required String authorId,
    required String authorUsername,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    @Default(0) int likeCount,
    @Default(false) bool isLikedByMe,
    required DateTime createdAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}
