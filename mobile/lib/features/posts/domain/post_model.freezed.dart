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
  @JsonKey(readValue: _readAuthorId)
  String get authorId => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readAuthorUsername)
  String get authorUsername => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readAuthorDisplayName)
  String get authorDisplayName => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readAuthorAvatarUrl)
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'caption', defaultValue: '')
  String get content => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  DateTime? get playedAt => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readGameId)
  String? get taggedGameId => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readGameTitle)
  String? get taggedGameName => throw _privateConstructorUsedError;
  int get likeCount => throw _privateConstructorUsedError;
  int get commentCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'likedByMe')
  bool get isLikedByMe => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

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
      @JsonKey(readValue: _readAuthorId) String authorId,
      @JsonKey(readValue: _readAuthorUsername) String authorUsername,
      @JsonKey(readValue: _readAuthorDisplayName) String authorDisplayName,
      @JsonKey(readValue: _readAuthorAvatarUrl) String? authorAvatarUrl,
      @JsonKey(name: 'caption', defaultValue: '') String content,
      String? location,
      DateTime? playedAt,
      List<String> imageUrls,
      @JsonKey(readValue: _readGameId) String? taggedGameId,
      @JsonKey(readValue: _readGameTitle) String? taggedGameName,
      int likeCount,
      int commentCount,
      @JsonKey(name: 'likedByMe') bool isLikedByMe,
      DateTime createdAt});
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
    Object? location = freezed,
    Object? playedAt = freezed,
    Object? imageUrls = null,
    Object? taggedGameId = freezed,
    Object? taggedGameName = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
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
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      playedAt: freezed == playedAt
          ? _value.playedAt
          : playedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
      @JsonKey(readValue: _readAuthorId) String authorId,
      @JsonKey(readValue: _readAuthorUsername) String authorUsername,
      @JsonKey(readValue: _readAuthorDisplayName) String authorDisplayName,
      @JsonKey(readValue: _readAuthorAvatarUrl) String? authorAvatarUrl,
      @JsonKey(name: 'caption', defaultValue: '') String content,
      String? location,
      DateTime? playedAt,
      List<String> imageUrls,
      @JsonKey(readValue: _readGameId) String? taggedGameId,
      @JsonKey(readValue: _readGameTitle) String? taggedGameName,
      int likeCount,
      int commentCount,
      @JsonKey(name: 'likedByMe') bool isLikedByMe,
      DateTime createdAt});
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
    Object? location = freezed,
    Object? playedAt = freezed,
    Object? imageUrls = null,
    Object? taggedGameId = freezed,
    Object? taggedGameName = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? isLikedByMe = null,
    Object? createdAt = null,
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
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      playedAt: freezed == playedAt
          ? _value.playedAt
          : playedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostImpl implements _Post {
  const _$PostImpl(
      {required this.id,
      @JsonKey(readValue: _readAuthorId) required this.authorId,
      @JsonKey(readValue: _readAuthorUsername) required this.authorUsername,
      @JsonKey(readValue: _readAuthorDisplayName)
      required this.authorDisplayName,
      @JsonKey(readValue: _readAuthorAvatarUrl) this.authorAvatarUrl,
      @JsonKey(name: 'caption', defaultValue: '') required this.content,
      this.location,
      this.playedAt,
      final List<String> imageUrls = const [],
      @JsonKey(readValue: _readGameId) this.taggedGameId,
      @JsonKey(readValue: _readGameTitle) this.taggedGameName,
      this.likeCount = 0,
      this.commentCount = 0,
      @JsonKey(name: 'likedByMe') this.isLikedByMe = false,
      required this.createdAt})
      : _imageUrls = imageUrls;

  factory _$PostImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(readValue: _readAuthorId)
  final String authorId;
  @override
  @JsonKey(readValue: _readAuthorUsername)
  final String authorUsername;
  @override
  @JsonKey(readValue: _readAuthorDisplayName)
  final String authorDisplayName;
  @override
  @JsonKey(readValue: _readAuthorAvatarUrl)
  final String? authorAvatarUrl;
  @override
  @JsonKey(name: 'caption', defaultValue: '')
  final String content;
  @override
  final String? location;
  @override
  final DateTime? playedAt;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  @JsonKey(readValue: _readGameId)
  final String? taggedGameId;
  @override
  @JsonKey(readValue: _readGameTitle)
  final String? taggedGameName;
  @override
  @JsonKey()
  final int likeCount;
  @override
  @JsonKey()
  final int commentCount;
  @override
  @JsonKey(name: 'likedByMe')
  final bool isLikedByMe;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Post(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, content: $content, location: $location, playedAt: $playedAt, imageUrls: $imageUrls, taggedGameId: $taggedGameId, taggedGameName: $taggedGameName, likeCount: $likeCount, commentCount: $commentCount, isLikedByMe: $isLikedByMe, createdAt: $createdAt)';
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
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.playedAt, playedAt) ||
                other.playedAt == playedAt) &&
            const DeepCollectionEquality()
                .equals(other._imageUrls, _imageUrls) &&
            (identical(other.taggedGameId, taggedGameId) ||
                other.taggedGameId == taggedGameId) &&
            (identical(other.taggedGameName, taggedGameName) ||
                other.taggedGameName == taggedGameName) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount) &&
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
      authorId,
      authorUsername,
      authorDisplayName,
      authorAvatarUrl,
      content,
      location,
      playedAt,
      const DeepCollectionEquality().hash(_imageUrls),
      taggedGameId,
      taggedGameName,
      likeCount,
      commentCount,
      isLikedByMe,
      createdAt);

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
      @JsonKey(readValue: _readAuthorId) required final String authorId,
      @JsonKey(readValue: _readAuthorUsername)
      required final String authorUsername,
      @JsonKey(readValue: _readAuthorDisplayName)
      required final String authorDisplayName,
      @JsonKey(readValue: _readAuthorAvatarUrl) final String? authorAvatarUrl,
      @JsonKey(name: 'caption', defaultValue: '') required final String content,
      final String? location,
      final DateTime? playedAt,
      final List<String> imageUrls,
      @JsonKey(readValue: _readGameId) final String? taggedGameId,
      @JsonKey(readValue: _readGameTitle) final String? taggedGameName,
      final int likeCount,
      final int commentCount,
      @JsonKey(name: 'likedByMe') final bool isLikedByMe,
      required final DateTime createdAt}) = _$PostImpl;

  factory _Post.fromJson(Map<String, dynamic> json) = _$PostImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(readValue: _readAuthorId)
  String get authorId;
  @override
  @JsonKey(readValue: _readAuthorUsername)
  String get authorUsername;
  @override
  @JsonKey(readValue: _readAuthorDisplayName)
  String get authorDisplayName;
  @override
  @JsonKey(readValue: _readAuthorAvatarUrl)
  String? get authorAvatarUrl;
  @override
  @JsonKey(name: 'caption', defaultValue: '')
  String get content;
  @override
  String? get location;
  @override
  DateTime? get playedAt;
  @override
  List<String> get imageUrls;
  @override
  @JsonKey(readValue: _readGameId)
  String? get taggedGameId;
  @override
  @JsonKey(readValue: _readGameTitle)
  String? get taggedGameName;
  @override
  int get likeCount;
  @override
  int get commentCount;
  @override
  @JsonKey(name: 'likedByMe')
  bool get isLikedByMe;
  @override
  DateTime get createdAt;

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
  String get authorId => throw _privateConstructorUsedError;
  String get authorUsername => throw _privateConstructorUsedError;
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'body')
  String get content => throw _privateConstructorUsedError;
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
      String authorId,
      String authorUsername,
      String? authorAvatarUrl,
      @JsonKey(name: 'body') String content,
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
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? createdAt = null,
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
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
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
      String authorId,
      String authorUsername,
      String? authorAvatarUrl,
      @JsonKey(name: 'body') String content,
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
    Object? authorId = null,
    Object? authorUsername = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? createdAt = null,
  }) {
    return _then(_$CommentImpl(
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
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
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
      required this.authorId,
      required this.authorUsername,
      this.authorAvatarUrl,
      @JsonKey(name: 'body') required this.content,
      required this.createdAt});

  factory _$CommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommentImplFromJson(json);

  @override
  final String id;
  @override
  final String authorId;
  @override
  final String authorUsername;
  @override
  final String? authorAvatarUrl;
  @override
  @JsonKey(name: 'body')
  final String content;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Comment(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorAvatarUrl: $authorAvatarUrl, content: $content, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.authorUsername, authorUsername) ||
                other.authorUsername == authorUsername) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, authorId, authorUsername,
      authorAvatarUrl, content, createdAt);

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
      required final String authorId,
      required final String authorUsername,
      final String? authorAvatarUrl,
      @JsonKey(name: 'body') required final String content,
      required final DateTime createdAt}) = _$CommentImpl;

  factory _Comment.fromJson(Map<String, dynamic> json) = _$CommentImpl.fromJson;

  @override
  String get id;
  @override
  String get authorId;
  @override
  String get authorUsername;
  @override
  String? get authorAvatarUrl;
  @override
  @JsonKey(name: 'body')
  String get content;
  @override
  DateTime get createdAt;

  /// Create a copy of Comment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommentImplCopyWith<_$CommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
