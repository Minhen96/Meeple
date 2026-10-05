// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

/// A post (`PostResponse`). Author and game fields are flattened from the
/// nested `author` / `game` objects.
@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    @JsonKey(readValue: _readAuthorId) required String authorId,
    @JsonKey(readValue: _readAuthorUsername) required String authorUsername,
    @JsonKey(readValue: _readAuthorDisplayName)
    required String authorDisplayName,
    @JsonKey(readValue: _readAuthorAvatarUrl) String? authorAvatarUrl,
    @JsonKey(name: 'caption', defaultValue: '') required String content,
    String? location,
    DateTime? playedAt,
    @Default([]) List<String> imageUrls,
    @JsonKey(readValue: _readGameId) String? taggedGameId,
    @JsonKey(readValue: _readGameTitle) String? taggedGameName,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @JsonKey(name: 'likedByMe') @Default(false) bool isLikedByMe,
    required DateTime createdAt,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}

/// A post comment (`PostCommentResponse`).
@freezed
class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String authorId,
    required String authorUsername,
    String? authorAvatarUrl,
    @JsonKey(name: 'body') required String content,
    required DateTime createdAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}

Object? _author(Map<dynamic, dynamic> json, String field) =>
    (json['author'] as Map?)?[field];

Object? _readAuthorId(Map<dynamic, dynamic> json, String key) =>
    _author(json, 'id');
Object? _readAuthorUsername(Map<dynamic, dynamic> json, String key) =>
    _author(json, 'username');
Object? _readAuthorDisplayName(Map<dynamic, dynamic> json, String key) =>
    _author(json, 'displayName') ?? _author(json, 'username');
Object? _readAuthorAvatarUrl(Map<dynamic, dynamic> json, String key) =>
    _author(json, 'avatarUrl');
Object? _readGameId(Map<dynamic, dynamic> json, String key) =>
    (json['game'] as Map?)?['id'];
Object? _readGameTitle(Map<dynamic, dynamic> json, String key) =>
    (json['game'] as Map?)?['title'];
