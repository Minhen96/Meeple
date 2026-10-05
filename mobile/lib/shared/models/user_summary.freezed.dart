// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserSummary _$UserSummaryFromJson(Map<String, dynamic> json) {
  return _UserSummary.fromJson(json);
}

/// @nodoc
mixin _$UserSummary {
  @JsonKey(defaultValue: '')
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readDisplayName)
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readDeleted)
  bool get deleted => throw _privateConstructorUsedError;
  @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
  FriendshipStatus get friendshipStatus => throw _privateConstructorUsedError;

  /// Serializes this UserSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserSummaryCopyWith<UserSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserSummaryCopyWith<$Res> {
  factory $UserSummaryCopyWith(
          UserSummary value, $Res Function(UserSummary) then) =
      _$UserSummaryCopyWithImpl<$Res, UserSummary>;
  @useResult
  $Res call(
      {@JsonKey(defaultValue: '') String id,
      String username,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      @JsonKey(readValue: _readDeleted) bool deleted,
      @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
      FriendshipStatus friendshipStatus});
}

/// @nodoc
class _$UserSummaryCopyWithImpl<$Res, $Val extends UserSummary>
    implements $UserSummaryCopyWith<$Res> {
  _$UserSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? deleted = null,
    Object? friendshipStatus = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      deleted: null == deleted
          ? _value.deleted
          : deleted // ignore: cast_nullable_to_non_nullable
              as bool,
      friendshipStatus: null == friendshipStatus
          ? _value.friendshipStatus
          : friendshipStatus // ignore: cast_nullable_to_non_nullable
              as FriendshipStatus,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserSummaryImplCopyWith<$Res>
    implements $UserSummaryCopyWith<$Res> {
  factory _$$UserSummaryImplCopyWith(
          _$UserSummaryImpl value, $Res Function(_$UserSummaryImpl) then) =
      __$$UserSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(defaultValue: '') String id,
      String username,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      @JsonKey(readValue: _readDeleted) bool deleted,
      @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
      FriendshipStatus friendshipStatus});
}

/// @nodoc
class __$$UserSummaryImplCopyWithImpl<$Res>
    extends _$UserSummaryCopyWithImpl<$Res, _$UserSummaryImpl>
    implements _$$UserSummaryImplCopyWith<$Res> {
  __$$UserSummaryImplCopyWithImpl(
      _$UserSummaryImpl _value, $Res Function(_$UserSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? deleted = null,
    Object? friendshipStatus = null,
  }) {
    return _then(_$UserSummaryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      deleted: null == deleted
          ? _value.deleted
          : deleted // ignore: cast_nullable_to_non_nullable
              as bool,
      friendshipStatus: null == friendshipStatus
          ? _value.friendshipStatus
          : friendshipStatus // ignore: cast_nullable_to_non_nullable
              as FriendshipStatus,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserSummaryImpl implements _UserSummary {
  const _$UserSummaryImpl(
      {@JsonKey(defaultValue: '') required this.id,
      this.username = '',
      @JsonKey(readValue: _readDisplayName) this.displayName = '',
      this.avatarUrl,
      @JsonKey(readValue: _readDeleted) this.deleted = false,
      @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
      this.friendshipStatus = FriendshipStatus.none});

  factory _$UserSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserSummaryImplFromJson(json);

  @override
  @JsonKey(defaultValue: '')
  final String id;
  @override
  @JsonKey()
  final String username;
  @override
  @JsonKey(readValue: _readDisplayName)
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  @JsonKey(readValue: _readDeleted)
  final bool deleted;
  @override
  @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
  final FriendshipStatus friendshipStatus;

  @override
  String toString() {
    return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, deleted: $deleted, friendshipStatus: $friendshipStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.deleted, deleted) || other.deleted == deleted) &&
            (identical(other.friendshipStatus, friendshipStatus) ||
                other.friendshipStatus == friendshipStatus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, username, displayName,
      avatarUrl, deleted, friendshipStatus);

  /// Create a copy of UserSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserSummaryImplCopyWith<_$UserSummaryImpl> get copyWith =>
      __$$UserSummaryImplCopyWithImpl<_$UserSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserSummaryImplToJson(
      this,
    );
  }
}

abstract class _UserSummary implements UserSummary {
  const factory _UserSummary(
      {@JsonKey(defaultValue: '') required final String id,
      final String username,
      @JsonKey(readValue: _readDisplayName) final String displayName,
      final String? avatarUrl,
      @JsonKey(readValue: _readDeleted) final bool deleted,
      @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
      final FriendshipStatus friendshipStatus}) = _$UserSummaryImpl;

  factory _UserSummary.fromJson(Map<String, dynamic> json) =
      _$UserSummaryImpl.fromJson;

  @override
  @JsonKey(defaultValue: '')
  String get id;
  @override
  String get username;
  @override
  @JsonKey(readValue: _readDisplayName)
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  @JsonKey(readValue: _readDeleted)
  bool get deleted;
  @override
  @JsonKey(fromJson: FriendshipStatus.parse, toJson: _statusToJson)
  FriendshipStatus get friendshipStatus;

  /// Create a copy of UserSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserSummaryImplCopyWith<_$UserSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
