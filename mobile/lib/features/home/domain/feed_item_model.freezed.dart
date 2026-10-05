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
  switch (json['kind']) {
    case 'post':
      return FeedPostItem.fromJson(json);
    case 'activity':
      return FeedActivityItem.fromJson(json);

    default:
      return FeedUnknownItem.fromJson(json);
  }
}

/// @nodoc
mixin _$FeedItem {
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DateTime createdAt, Post post) post,
    required TResult Function(DateTime createdAt, FeedActivity activity)
        activity,
    required TResult Function(DateTime? createdAt) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DateTime createdAt, Post post)? post,
    TResult? Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult? Function(DateTime? createdAt)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DateTime createdAt, Post post)? post,
    TResult Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult Function(DateTime? createdAt)? unknown,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedPostItem value) post,
    required TResult Function(FeedActivityItem value) activity,
    required TResult Function(FeedUnknownItem value) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedPostItem value)? post,
    TResult? Function(FeedActivityItem value)? activity,
    TResult? Function(FeedUnknownItem value)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedPostItem value)? post,
    TResult Function(FeedActivityItem value)? activity,
    TResult Function(FeedUnknownItem value)? unknown,
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
  $Res call({DateTime createdAt});
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
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      createdAt: null == createdAt
          ? _value.createdAt!
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeedPostItemImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedPostItemImplCopyWith(
          _$FeedPostItemImpl value, $Res Function(_$FeedPostItemImpl) then) =
      __$$FeedPostItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime createdAt, Post post});

  $PostCopyWith<$Res> get post;
}

/// @nodoc
class __$$FeedPostItemImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedPostItemImpl>
    implements _$$FeedPostItemImplCopyWith<$Res> {
  __$$FeedPostItemImplCopyWithImpl(
      _$FeedPostItemImpl _value, $Res Function(_$FeedPostItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? post = null,
  }) {
    return _then(_$FeedPostItemImpl(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      post: null == post
          ? _value.post
          : post // ignore: cast_nullable_to_non_nullable
              as Post,
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
class _$FeedPostItemImpl implements FeedPostItem {
  const _$FeedPostItemImpl(
      {required this.createdAt, required this.post, final String? $type})
      : $type = $type ?? 'post';

  factory _$FeedPostItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedPostItemImplFromJson(json);

  @override
  final DateTime createdAt;
  @override
  final Post post;

  @JsonKey(name: 'kind')
  final String $type;

  @override
  String toString() {
    return 'FeedItem.post(createdAt: $createdAt, post: $post)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedPostItemImpl &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.post, post) || other.post == post));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, createdAt, post);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedPostItemImplCopyWith<_$FeedPostItemImpl> get copyWith =>
      __$$FeedPostItemImplCopyWithImpl<_$FeedPostItemImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DateTime createdAt, Post post) post,
    required TResult Function(DateTime createdAt, FeedActivity activity)
        activity,
    required TResult Function(DateTime? createdAt) unknown,
  }) {
    return post(createdAt, this.post);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DateTime createdAt, Post post)? post,
    TResult? Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult? Function(DateTime? createdAt)? unknown,
  }) {
    return post?.call(createdAt, this.post);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DateTime createdAt, Post post)? post,
    TResult Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult Function(DateTime? createdAt)? unknown,
    required TResult orElse(),
  }) {
    if (post != null) {
      return post(createdAt, this.post);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedPostItem value) post,
    required TResult Function(FeedActivityItem value) activity,
    required TResult Function(FeedUnknownItem value) unknown,
  }) {
    return post(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedPostItem value)? post,
    TResult? Function(FeedActivityItem value)? activity,
    TResult? Function(FeedUnknownItem value)? unknown,
  }) {
    return post?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedPostItem value)? post,
    TResult Function(FeedActivityItem value)? activity,
    TResult Function(FeedUnknownItem value)? unknown,
    required TResult orElse(),
  }) {
    if (post != null) {
      return post(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedPostItemImplToJson(
      this,
    );
  }
}

abstract class FeedPostItem implements FeedItem {
  const factory FeedPostItem(
      {required final DateTime createdAt,
      required final Post post}) = _$FeedPostItemImpl;

  factory FeedPostItem.fromJson(Map<String, dynamic> json) =
      _$FeedPostItemImpl.fromJson;

  @override
  DateTime get createdAt;
  Post get post;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedPostItemImplCopyWith<_$FeedPostItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FeedActivityItemImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedActivityItemImplCopyWith(_$FeedActivityItemImpl value,
          $Res Function(_$FeedActivityItemImpl) then) =
      __$$FeedActivityItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime createdAt, FeedActivity activity});

  $FeedActivityCopyWith<$Res> get activity;
}

/// @nodoc
class __$$FeedActivityItemImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedActivityItemImpl>
    implements _$$FeedActivityItemImplCopyWith<$Res> {
  __$$FeedActivityItemImplCopyWithImpl(_$FeedActivityItemImpl _value,
      $Res Function(_$FeedActivityItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? activity = null,
  }) {
    return _then(_$FeedActivityItemImpl(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      activity: null == activity
          ? _value.activity
          : activity // ignore: cast_nullable_to_non_nullable
              as FeedActivity,
    ));
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedActivityCopyWith<$Res> get activity {
    return $FeedActivityCopyWith<$Res>(_value.activity, (value) {
      return _then(_value.copyWith(activity: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedActivityItemImpl implements FeedActivityItem {
  const _$FeedActivityItemImpl(
      {required this.createdAt, required this.activity, final String? $type})
      : $type = $type ?? 'activity';

  factory _$FeedActivityItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedActivityItemImplFromJson(json);

  @override
  final DateTime createdAt;
  @override
  final FeedActivity activity;

  @JsonKey(name: 'kind')
  final String $type;

  @override
  String toString() {
    return 'FeedItem.activity(createdAt: $createdAt, activity: $activity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedActivityItemImpl &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.activity, activity) ||
                other.activity == activity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, createdAt, activity);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedActivityItemImplCopyWith<_$FeedActivityItemImpl> get copyWith =>
      __$$FeedActivityItemImplCopyWithImpl<_$FeedActivityItemImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DateTime createdAt, Post post) post,
    required TResult Function(DateTime createdAt, FeedActivity activity)
        activity,
    required TResult Function(DateTime? createdAt) unknown,
  }) {
    return activity(createdAt, this.activity);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DateTime createdAt, Post post)? post,
    TResult? Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult? Function(DateTime? createdAt)? unknown,
  }) {
    return activity?.call(createdAt, this.activity);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DateTime createdAt, Post post)? post,
    TResult Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult Function(DateTime? createdAt)? unknown,
    required TResult orElse(),
  }) {
    if (activity != null) {
      return activity(createdAt, this.activity);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedPostItem value) post,
    required TResult Function(FeedActivityItem value) activity,
    required TResult Function(FeedUnknownItem value) unknown,
  }) {
    return activity(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedPostItem value)? post,
    TResult? Function(FeedActivityItem value)? activity,
    TResult? Function(FeedUnknownItem value)? unknown,
  }) {
    return activity?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedPostItem value)? post,
    TResult Function(FeedActivityItem value)? activity,
    TResult Function(FeedUnknownItem value)? unknown,
    required TResult orElse(),
  }) {
    if (activity != null) {
      return activity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedActivityItemImplToJson(
      this,
    );
  }
}

abstract class FeedActivityItem implements FeedItem {
  const factory FeedActivityItem(
      {required final DateTime createdAt,
      required final FeedActivity activity}) = _$FeedActivityItemImpl;

  factory FeedActivityItem.fromJson(Map<String, dynamic> json) =
      _$FeedActivityItemImpl.fromJson;

  @override
  DateTime get createdAt;
  FeedActivity get activity;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedActivityItemImplCopyWith<_$FeedActivityItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FeedUnknownItemImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedUnknownItemImplCopyWith(_$FeedUnknownItemImpl value,
          $Res Function(_$FeedUnknownItemImpl) then) =
      __$$FeedUnknownItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime? createdAt});
}

/// @nodoc
class __$$FeedUnknownItemImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedUnknownItemImpl>
    implements _$$FeedUnknownItemImplCopyWith<$Res> {
  __$$FeedUnknownItemImplCopyWithImpl(
      _$FeedUnknownItemImpl _value, $Res Function(_$FeedUnknownItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = freezed,
  }) {
    return _then(_$FeedUnknownItemImpl(
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedUnknownItemImpl implements FeedUnknownItem {
  const _$FeedUnknownItemImpl({this.createdAt, final String? $type})
      : $type = $type ?? 'unknown';

  factory _$FeedUnknownItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedUnknownItemImplFromJson(json);

  @override
  final DateTime? createdAt;

  @JsonKey(name: 'kind')
  final String $type;

  @override
  String toString() {
    return 'FeedItem.unknown(createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedUnknownItemImpl &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, createdAt);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedUnknownItemImplCopyWith<_$FeedUnknownItemImpl> get copyWith =>
      __$$FeedUnknownItemImplCopyWithImpl<_$FeedUnknownItemImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DateTime createdAt, Post post) post,
    required TResult Function(DateTime createdAt, FeedActivity activity)
        activity,
    required TResult Function(DateTime? createdAt) unknown,
  }) {
    return unknown(createdAt);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DateTime createdAt, Post post)? post,
    TResult? Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult? Function(DateTime? createdAt)? unknown,
  }) {
    return unknown?.call(createdAt);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DateTime createdAt, Post post)? post,
    TResult Function(DateTime createdAt, FeedActivity activity)? activity,
    TResult Function(DateTime? createdAt)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(createdAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FeedPostItem value) post,
    required TResult Function(FeedActivityItem value) activity,
    required TResult Function(FeedUnknownItem value) unknown,
  }) {
    return unknown(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FeedPostItem value)? post,
    TResult? Function(FeedActivityItem value)? activity,
    TResult? Function(FeedUnknownItem value)? unknown,
  }) {
    return unknown?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FeedPostItem value)? post,
    TResult Function(FeedActivityItem value)? activity,
    TResult Function(FeedUnknownItem value)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedUnknownItemImplToJson(
      this,
    );
  }
}

abstract class FeedUnknownItem implements FeedItem {
  const factory FeedUnknownItem({final DateTime? createdAt}) =
      _$FeedUnknownItemImpl;

  factory FeedUnknownItem.fromJson(Map<String, dynamic> json) =
      _$FeedUnknownItemImpl.fromJson;

  @override
  DateTime? get createdAt;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedUnknownItemImplCopyWith<_$FeedUnknownItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedActivity _$FeedActivityFromJson(Map<String, dynamic> json) {
  return _FeedActivity.fromJson(json);
}

/// @nodoc
mixin _$FeedActivity {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  @JsonKey(readValue: readUserOrDeleted)
  UserSummary get user => throw _privateConstructorUsedError;
  Map<String, dynamic> get data => throw _privateConstructorUsedError;

  /// Serializes this FeedActivity to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedActivityCopyWith<FeedActivity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedActivityCopyWith<$Res> {
  factory $FeedActivityCopyWith(
          FeedActivity value, $Res Function(FeedActivity) then) =
      _$FeedActivityCopyWithImpl<$Res, FeedActivity>;
  @useResult
  $Res call(
      {String id,
      String type,
      @JsonKey(readValue: readUserOrDeleted) UserSummary user,
      Map<String, dynamic> data});

  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class _$FeedActivityCopyWithImpl<$Res, $Val extends FeedActivity>
    implements $FeedActivityCopyWith<$Res> {
  _$FeedActivityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? user = null,
    Object? data = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserSummaryCopyWith<$Res> get user {
    return $UserSummaryCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeedActivityImplCopyWith<$Res>
    implements $FeedActivityCopyWith<$Res> {
  factory _$$FeedActivityImplCopyWith(
          _$FeedActivityImpl value, $Res Function(_$FeedActivityImpl) then) =
      __$$FeedActivityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      @JsonKey(readValue: readUserOrDeleted) UserSummary user,
      Map<String, dynamic> data});

  @override
  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class __$$FeedActivityImplCopyWithImpl<$Res>
    extends _$FeedActivityCopyWithImpl<$Res, _$FeedActivityImpl>
    implements _$$FeedActivityImplCopyWith<$Res> {
  __$$FeedActivityImplCopyWithImpl(
      _$FeedActivityImpl _value, $Res Function(_$FeedActivityImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? user = null,
    Object? data = null,
  }) {
    return _then(_$FeedActivityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedActivityImpl extends _FeedActivity {
  const _$FeedActivityImpl(
      {required this.id,
      required this.type,
      @JsonKey(readValue: readUserOrDeleted) required this.user,
      final Map<String, dynamic> data = const <String, dynamic>{}})
      : _data = data,
        super._();

  factory _$FeedActivityImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedActivityImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  @JsonKey(readValue: readUserOrDeleted)
  final UserSummary user;
  final Map<String, dynamic> _data;
  @override
  @JsonKey()
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  @override
  String toString() {
    return 'FeedActivity(id: $id, type: $type, user: $user, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedActivityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.user, user) || other.user == user) &&
            const DeepCollectionEquality().equals(other._data, _data));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, type, user, const DeepCollectionEquality().hash(_data));

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedActivityImplCopyWith<_$FeedActivityImpl> get copyWith =>
      __$$FeedActivityImplCopyWithImpl<_$FeedActivityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedActivityImplToJson(
      this,
    );
  }
}

abstract class _FeedActivity extends FeedActivity {
  const factory _FeedActivity(
      {required final String id,
      required final String type,
      @JsonKey(readValue: readUserOrDeleted) required final UserSummary user,
      final Map<String, dynamic> data}) = _$FeedActivityImpl;
  const _FeedActivity._() : super._();

  factory _FeedActivity.fromJson(Map<String, dynamic> json) =
      _$FeedActivityImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  @JsonKey(readValue: readUserOrDeleted)
  UserSummary get user;
  @override
  Map<String, dynamic> get data;

  /// Create a copy of FeedActivity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedActivityImplCopyWith<_$FeedActivityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
