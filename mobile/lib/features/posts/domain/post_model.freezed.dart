// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Post _$PostFromJson(Map<String, dynamic> json) {
  return _Post.fromJson(json);
}

/// @nodoc
mixin _$Post {
  String get id => throw _privateConstructorUsedError;
  String get authorId => throw _privateConstructorUsedError;
  String get authorUsername => throw _privateConstructorUsedError;
  String get authorDisplayName => throw _privateConstructorUsedError;
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  String? get taggedGameId => throw _privateConstructorUsedError;
  String? get taggedGameName => throw _privateConstructorUsedError;
  String? get linkedEventId => throw _privateConstructorUsedError;
  int get likeCount => throw _privateConstructorUsedError;
  int get commentCount => throw _privateConstructorUsedError;
  bool get isLikedByMe => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PostCopyWith<Post> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostCopyWith<$Res> {
  factory $PostCopyWith(Post value, $Res Function(Post) then) =
      _$PostCopyWithImpl<$Res, Post>;
  @useResult
  $Res call(
      {String id,
      String authorId,
      String authorUsername,
      String authorDisplayName,
      String? authorAvatarUrl,
      String content,
      List<String> imageUrls,
      String? taggedGameId,
      String? taggedGameName,
      String? linkedEventId,
      int likeCount,
      int commentCount,
      bool isLikedByMe,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$PostCopyWithImpl<$Res, $Val extends Post>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorDisplayName = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? imageUrls = null,
    Object? taggedGameId = freezed,
    Object? taggedGameName = freezed,
    Object? linkedEventId = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      authorUsername: null == authorUsername
          ? _value.authorUsername
          : authorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      authorDisplayName: null == authorDisplayName
          ? _value.authorDisplayName
          : authorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrls: null == imageUrls
          ? _value.imageUrls
          : imageUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      taggedGameId: freezed == taggedGameId
          ? _value.taggedGameId
          : taggedGameId // ignore: cast_nullable_to_non_nullable
              as String?,
      taggedGameName: freezed == taggedGameName
          ? _value.taggedGameName
          : taggedGameName // ignore: cast_nullable_to_non_nullable
              as String?,
      linkedEventId: freezed == linkedEventId
          ? _value.linkedEventId
          : linkedEventId // ignore: cast_nullable_to_non_nullable
              as String?,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      commentCount: null == commentCount
          ? _value.commentCount
          : commentCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLikedByMe: null == isLikedByMe
          ? _value.isLikedByMe
          : isLikedByMe // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PostImplCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$$PostImplCopyWith(
          _$PostImpl value, $Res Function(_$PostImpl) then) =
      __$$PostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String authorId,
      String authorUsername,
      String authorDisplayName,
      String? authorAvatarUrl,
      String content,
      List<String> imageUrls,
      String? taggedGameId,
      String? taggedGameName,
      String? linkedEventId,
      int likeCount,
      int commentCount,
      bool isLikedByMe,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$PostImplCopyWithImpl<$Res>
    extends _$PostCopyWithImpl<$Res, _$PostImpl>
    implements _$$PostImplCopyWith<$Res> {
  __$$PostImplCopyWithImpl(_$PostImpl _value, $Res Function(_$PostImpl) _then)
      : super(_value, _then);

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorDisplayName = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? imageUrls = null,
    Object? taggedGameId = freezed,
    Object? taggedGameName = freezed,
    Object? linkedEventId = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$PostImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      authorUsername: null == authorUsername
          ? _value.authorUsername
          : authorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      authorDisplayName: null == authorDisplayName
          ? _value.authorDisplayName
          : authorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrls: null == imageUrls
          ? _value._imageUrls
          : imageUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      taggedGameId: freezed == taggedGameId
          ? _value.taggedGameId
          : taggedGameId // ignore: cast_nullable_to_non_nullable
              as String?,
      taggedGameName: freezed == taggedGameName
          ? _value.taggedGameName
          : taggedGameName // ignore: cast_nullable_to_non_nullable
              as String?,
      linkedEventId: freezed == linkedEventId
          ? _value.linkedEventId
          : linkedEventId // ignore: cast_nullable_to_non_nullable
              as String?,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      commentCount: null == commentCount
          ? _value.commentCount
          : commentCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLikedByMe: null == isLikedByMe
          ? _value.isLikedByMe
          : isLikedByMe // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostImpl implements _Post {
  const _$PostImpl(
      {required this.id,
      required this.authorId,
      required this.authorUsername,
      required this.authorDisplayName,
      this.authorAvatarUrl,
      required this.content,
      final List<String> imageUrls = const [],
      this.taggedGameId,
      this.taggedGameName,
      this.linkedEventId,
      this.likeCount = 0,
      this.commentCount = 0,
      this.isLikedByMe = false,
      required this.createdAt,
      this.updatedAt})
      : _imageUrls = imageUrls;

  factory _$PostImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostImplFromJson(json);

  @override
  final String id;
  @override
  final String authorId;
  @override
  final String authorUsername;
  @override
  final String authorDisplayName;
  @override
  final String? authorAvatarUrl;
  @override
  final String content;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  final String? taggedGameId;
  @override
  final String? taggedGameName;
  @override
  final String? linkedEventId;
  @override
  @JsonKey()
  final int likeCount;
  @override
  @JsonKey()
  final int commentCount;
  @override
  @JsonKey()
  final bool isLikedByMe;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Post(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, content: $content, imageUrls: $imageUrls, taggedGameId: $taggedGameId, taggedGameName: $taggedGameName, linkedEventId: $linkedEventId, likeCount: $likeCount, commentCount: $commentCount, isLikedByMe: $isLikedByMe, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.authorUsername, authorUsername) ||
                other.authorUsername == authorUsername) &&
            (identical(other.authorDisplayName, authorDisplayName) ||
                other.authorDisplayName == authorDisplayName) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other._imageUrls, _imageUrls) &&
            (identical(other.taggedGameId, taggedGameId) ||
                other.taggedGameId == taggedGameId) &&
            (identical(other.taggedGameName, taggedGameName) ||
                other.taggedGameName == taggedGameName) &&
            (identical(other.linkedEventId, linkedEventId) ||
                other.linkedEventId == linkedEventId) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount) &&
            (identical(other.isLikedByMe, isLikedByMe) ||
                other.isLikedByMe == isLikedByMe) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      authorId,
      authorUsername,
      authorDisplayName,
      authorAvatarUrl,
      content,
      const DeepCollectionEquality().hash(_imageUrls),
      taggedGameId,
      taggedGameName,
      linkedEventId,
      likeCount,
      commentCount,
      isLikedByMe,
      createdAt,
      updatedAt);

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      __$$PostImplCopyWithImpl<_$PostImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostImplToJson(
      this,
    );
  }
}

abstract class _Post implements Post {
  const factory _Post(
      {required final String id,
      required final String authorId,
      required final String authorUsername,
      required final String authorDisplayName,
      final String? authorAvatarUrl,
      required final String content,
      final List<String> imageUrls,
      final String? taggedGameId,
      final String? taggedGameName,
      final String? linkedEventId,
      final int likeCount,
      final int commentCount,
      final bool isLikedByMe,
      required final DateTime createdAt,
      final DateTime? updatedAt}) = _$PostImpl;

  factory _Post.fromJson(Map<String, dynamic> json) = _$PostImpl.fromJson;

  @override
  String get id;
  @override
  String get authorId;
  @override
  String get authorUsername;
  @override
  String get authorDisplayName;
  @override
  String? get authorAvatarUrl;
  @override
  String get content;
  @override
  List<String> get imageUrls;
  @override
  String? get taggedGameId;
  @override
  String? get taggedGameName;
  @override
  String? get linkedEventId;
  @override
  int get likeCount;
  @override
  int get commentCount;
  @override
  bool get isLikedByMe;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Comment _$CommentFromJson(Map<String, dynamic> json) {
  return _Comment.fromJson(json);
}

/// @nodoc
mixin _$Comment {
  String get id => throw _privateConstructorUsedError;
  String get postId => throw _privateConstructorUsedError;
  String get authorId => throw _privateConstructorUsedError;
  String get authorUsername => throw _privateConstructorUsedError;
  String get authorDisplayName => throw _privateConstructorUsedError;
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  int get likeCount => throw _privateConstructorUsedError;
  bool get isLikedByMe => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Comment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommentCopyWith<Comment> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommentCopyWith<$Res> {
  factory $CommentCopyWith(Comment value, $Res Function(Comment) then) =
      _$CommentCopyWithImpl<$Res, Comment>;
  @useResult
  $Res call(
      {String id,
      String postId,
      String authorId,
      String authorUsername,
      String authorDisplayName,
      String? authorAvatarUrl,
      String content,
      int likeCount,
      bool isLikedByMe,
      DateTime createdAt});
}

/// @nodoc
class _$CommentCopyWithImpl<$Res, $Val extends Comment>
    implements $CommentCopyWith<$Res> {
  _$CommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? postId = null,
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorDisplayName = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? likeCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      postId: null == postId
          ? _value.postId
          : postId // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      authorUsername: null == authorUsername
          ? _value.authorUsername
          : authorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      authorDisplayName: null == authorDisplayName
          ? _value.authorDisplayName
          : authorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLikedByMe: null == isLikedByMe
          ? _value.isLikedByMe
          : isLikedByMe // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommentImplCopyWith<$Res> implements $CommentCopyWith<$Res> {
  factory _$$CommentImplCopyWith(
          _$CommentImpl value, $Res Function(_$CommentImpl) then) =
      __$$CommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String postId,
      String authorId,
      String authorUsername,
      String authorDisplayName,
      String? authorAvatarUrl,
      String content,
      int likeCount,
      bool isLikedByMe,
      DateTime createdAt});
}

/// @nodoc
class __$$CommentImplCopyWithImpl<$Res>
    extends _$CommentCopyWithImpl<$Res, _$CommentImpl>
    implements _$$CommentImplCopyWith<$Res> {
  __$$CommentImplCopyWithImpl(
      _$CommentImpl _value, $Res Function(_$CommentImpl) _then)
      : super(_value, _then);

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? postId = null,
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorDisplayName = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? likeCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
  }) {
    return _then(_$CommentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      postId: null == postId
          ? _value.postId
          : postId // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      authorUsername: null == authorUsername
          ? _value.authorUsername
          : authorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      authorDisplayName: null == authorDisplayName
          ? _value.authorDisplayName
          : authorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLikedByMe: null == isLikedByMe
          ? _value.isLikedByMe
          : isLikedByMe // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommentImpl implements _Comment {
  const _$CommentImpl(
      {required this.id,
      required this.postId,
      required this.authorId,
      required this.authorUsername,
      required this.authorDisplayName,
      this.authorAvatarUrl,
      required this.content,
      this.likeCount = 0,
      this.isLikedByMe = false,
      required this.createdAt});

  factory _$CommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommentImplFromJson(json);

  @override
  final String id;
  @override
  final String postId;
  @override
  final String authorId;
  @override
  final String authorUsername;
  @override
  final String authorDisplayName;
  @override
  final String? authorAvatarUrl;
  @override
  final String content;
  @override
  @JsonKey()
  final int likeCount;
  @override
  @JsonKey()
  final bool isLikedByMe;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Comment(id: $id, postId: $postId, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, content: $content, likeCount: $likeCount, isLikedByMe: $isLikedByMe, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.postId, postId) || other.postId == postId) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.authorUsername, authorUsername) ||
                other.authorUsername == authorUsername) &&
            (identical(other.authorDisplayName, authorDisplayName) ||
                other.authorDisplayName == authorDisplayName) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.isLikedByMe, isLikedByMe) ||
                other.isLikedByMe == isLikedByMe) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      postId,
      authorId,
      authorUsername,
      authorDisplayName,
      authorAvatarUrl,
      content,
      likeCount,
      isLikedByMe,
      createdAt);

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommentImplCopyWith<_$CommentImpl> get copyWith =>
      __$$CommentImplCopyWithImpl<_$CommentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommentImplToJson(
      this,
    );
  }
}

abstract class _Comment implements Comment {
  const factory _Comment(
      {required final String id,
      required final String postId,
      required final String authorId,
      required final String authorUsername,
      required final String authorDisplayName,
      final String? authorAvatarUrl,
      required final String content,
      final int likeCount,
      final bool isLikedByMe,
      required final DateTime createdAt}) = _$CommentImpl;

  factory _Comment.fromJson(Map<String, dynamic> json) = _$CommentImpl.fromJson;

  @override
  String get id;
  @override
  String get postId;
  @override
  String get authorId;
  @override
  String get authorUsername;
  @override
  String get authorDisplayName;
  @override
  String? get authorAvatarUrl;
  @override
  String get content;
  @override
  int get likeCount;
  @override
  bool get isLikedByMe;
  @override
  DateTime get createdAt;

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommentImplCopyWith<_$CommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
