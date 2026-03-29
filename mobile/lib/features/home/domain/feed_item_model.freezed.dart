// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FeedItem _$FeedItemFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'post':
      return FeedItemPost.fromJson(json);
    case 'activity':
      return FeedItemActivity.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'FeedItem',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$FeedItem {
  String get id => throw _privateConstructorUsedError;
  DateTime get feedAt => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, Post post, DateTime feedAt) post,
    required TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)
        activity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, Post post, DateTime feedAt)? post,
    TResult? Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, Post post, DateTime feedAt)? post,
    TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedItemPost value) post,
    required TResult Function(FeedItemActivity value) activity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedItemPost value)? post,
    TResult? Function(FeedItemActivity value)? activity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedItemPost value)? post,
    TResult Function(FeedItemActivity value)? activity,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this FeedItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedItemCopyWith<FeedItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedItemCopyWith<$Res> {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) then) =
      _$FeedItemCopyWithImpl<$Res, FeedItem>;
  @useResult
  $Res call({String id, DateTime feedAt});
}

/// @nodoc
class _$FeedItemCopyWithImpl<$Res, $Val extends FeedItem>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? feedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      feedAt: null == feedAt
          ? _value.feedAt
          : feedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeedItemPostImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedItemPostImplCopyWith(
          _$FeedItemPostImpl value, $Res Function(_$FeedItemPostImpl) then) =
      __$$FeedItemPostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, Post post, DateTime feedAt});

  $PostCopyWith<$Res> get post;
}

/// @nodoc
class __$$FeedItemPostImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedItemPostImpl>
    implements _$$FeedItemPostImplCopyWith<$Res> {
  __$$FeedItemPostImplCopyWithImpl(
      _$FeedItemPostImpl _value, $Res Function(_$FeedItemPostImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? post = null,
    Object? feedAt = null,
  }) {
    return _then(_$FeedItemPostImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      post: null == post
          ? _value.post
          : post // ignore: cast_nullable_to_non_nullable
              as Post,
      feedAt: null == feedAt
          ? _value.feedAt
          : feedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PostCopyWith<$Res> get post {
    return $PostCopyWith<$Res>(_value.post, (value) {
      return _then(_value.copyWith(post: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedItemPostImpl implements FeedItemPost {
  const _$FeedItemPostImpl(
      {required this.id,
      required this.post,
      required this.feedAt,
      final String? $type})
      : $type = $type ?? 'post';

  factory _$FeedItemPostImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedItemPostImplFromJson(json);

  @override
  final String id;
  @override
  final Post post;
  @override
  final DateTime feedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'FeedItem.post(id: $id, post: $post, feedAt: $feedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedItemPostImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.post, post) || other.post == post) &&
            (identical(other.feedAt, feedAt) || other.feedAt == feedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, post, feedAt);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedItemPostImplCopyWith<_$FeedItemPostImpl> get copyWith =>
      __$$FeedItemPostImplCopyWithImpl<_$FeedItemPostImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, Post post, DateTime feedAt) post,
    required TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)
        activity,
  }) {
    return post(id, this.post, feedAt);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, Post post, DateTime feedAt)? post,
    TResult? Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
  }) {
    return post?.call(id, this.post, feedAt);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, Post post, DateTime feedAt)? post,
    TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
    required TResult orElse(),
  }) {
    if (post != null) {
      return post(id, this.post, feedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedItemPost value) post,
    required TResult Function(FeedItemActivity value) activity,
  }) {
    return post(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedItemPost value)? post,
    TResult? Function(FeedItemActivity value)? activity,
  }) {
    return post?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedItemPost value)? post,
    TResult Function(FeedItemActivity value)? activity,
    required TResult orElse(),
  }) {
    if (post != null) {
      return post(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedItemPostImplToJson(
      this,
    );
  }
}

abstract class FeedItemPost implements FeedItem {
  const factory FeedItemPost(
      {required final String id,
      required final Post post,
      required final DateTime feedAt}) = _$FeedItemPostImpl;

  factory FeedItemPost.fromJson(Map<String, dynamic> json) =
      _$FeedItemPostImpl.fromJson;

  @override
  String get id;
  Post get post;
  @override
  DateTime get feedAt;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedItemPostImplCopyWith<_$FeedItemPostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FeedItemActivityImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedItemActivityImplCopyWith(_$FeedItemActivityImpl value,
          $Res Function(_$FeedItemActivityImpl) then) =
      __$$FeedItemActivityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String actorId,
      String actorDisplayName,
      String? actorAvatarUrl,
      String activityType,
      String description,
      String? targetId,
      DateTime feedAt});
}

/// @nodoc
class __$$FeedItemActivityImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedItemActivityImpl>
    implements _$$FeedItemActivityImplCopyWith<$Res> {
  __$$FeedItemActivityImplCopyWithImpl(_$FeedItemActivityImpl _value,
      $Res Function(_$FeedItemActivityImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? actorId = null,
    Object? actorDisplayName = null,
    Object? actorAvatarUrl = freezed,
    Object? activityType = null,
    Object? description = null,
    Object? targetId = freezed,
    Object? feedAt = null,
  }) {
    return _then(_$FeedItemActivityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      actorId: null == actorId
          ? _value.actorId
          : actorId // ignore: cast_nullable_to_non_nullable
              as String,
      actorDisplayName: null == actorDisplayName
          ? _value.actorDisplayName
          : actorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      actorAvatarUrl: freezed == actorAvatarUrl
          ? _value.actorAvatarUrl
          : actorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      activityType: null == activityType
          ? _value.activityType
          : activityType // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      targetId: freezed == targetId
          ? _value.targetId
          : targetId // ignore: cast_nullable_to_non_nullable
              as String?,
      feedAt: null == feedAt
          ? _value.feedAt
          : feedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedItemActivityImpl implements FeedItemActivity {
  const _$FeedItemActivityImpl(
      {required this.id,
      required this.actorId,
      required this.actorDisplayName,
      this.actorAvatarUrl,
      required this.activityType,
      required this.description,
      this.targetId,
      required this.feedAt,
      final String? $type})
      : $type = $type ?? 'activity';

  factory _$FeedItemActivityImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedItemActivityImplFromJson(json);

  @override
  final String id;
  @override
  final String actorId;
  @override
  final String actorDisplayName;
  @override
  final String? actorAvatarUrl;
  @override
  final String activityType;
  @override
  final String description;
  @override
  final String? targetId;
  @override
  final DateTime feedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'FeedItem.activity(id: $id, actorId: $actorId, actorDisplayName: $actorDisplayName, actorAvatarUrl: $actorAvatarUrl, activityType: $activityType, description: $description, targetId: $targetId, feedAt: $feedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedItemActivityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.actorId, actorId) || other.actorId == actorId) &&
            (identical(other.actorDisplayName, actorDisplayName) ||
                other.actorDisplayName == actorDisplayName) &&
            (identical(other.actorAvatarUrl, actorAvatarUrl) ||
                other.actorAvatarUrl == actorAvatarUrl) &&
            (identical(other.activityType, activityType) ||
                other.activityType == activityType) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            (identical(other.feedAt, feedAt) || other.feedAt == feedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, actorId, actorDisplayName,
      actorAvatarUrl, activityType, description, targetId, feedAt);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedItemActivityImplCopyWith<_$FeedItemActivityImpl> get copyWith =>
      __$$FeedItemActivityImplCopyWithImpl<_$FeedItemActivityImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, Post post, DateTime feedAt) post,
    required TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)
        activity,
  }) {
    return activity(id, actorId, actorDisplayName, actorAvatarUrl, activityType,
        description, targetId, feedAt);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, Post post, DateTime feedAt)? post,
    TResult? Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
  }) {
    return activity?.call(id, actorId, actorDisplayName, actorAvatarUrl,
        activityType, description, targetId, feedAt);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, Post post, DateTime feedAt)? post,
    TResult Function(
            String id,
            String actorId,
            String actorDisplayName,
            String? actorAvatarUrl,
            String activityType,
            String description,
            String? targetId,
            DateTime feedAt)?
        activity,
    required TResult orElse(),
  }) {
    if (activity != null) {
      return activity(id, actorId, actorDisplayName, actorAvatarUrl,
          activityType, description, targetId, feedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedItemPost value) post,
    required TResult Function(FeedItemActivity value) activity,
  }) {
    return activity(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedItemPost value)? post,
    TResult? Function(FeedItemActivity value)? activity,
  }) {
    return activity?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedItemPost value)? post,
    TResult Function(FeedItemActivity value)? activity,
    required TResult orElse(),
  }) {
    if (activity != null) {
      return activity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedItemActivityImplToJson(
      this,
    );
  }
}

abstract class FeedItemActivity implements FeedItem {
  const factory FeedItemActivity(
      {required final String id,
      required final String actorId,
      required final String actorDisplayName,
      final String? actorAvatarUrl,
      required final String activityType,
      required final String description,
      final String? targetId,
      required final DateTime feedAt}) = _$FeedItemActivityImpl;

  factory FeedItemActivity.fromJson(Map<String, dynamic> json) =
      _$FeedItemActivityImpl.fromJson;

  @override
  String get id;
  String get actorId;
  String get actorDisplayName;
  String? get actorAvatarUrl;
  String get activityType;
  String get description;
  String? get targetId;
  @override
  DateTime get feedAt;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedItemActivityImplCopyWith<_$FeedItemActivityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
