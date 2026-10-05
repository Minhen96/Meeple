// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readDisplayName)
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  bool get onboardingCompleted => throw _privateConstructorUsedError;
  bool get isAdmin => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;

  /// `en` | `zh-CN`.
  String? get preferredLanguage => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  DateTime? get usernameChangeAvailableAt => throw _privateConstructorUsedError;

  /// Self only (null on other users' profiles).
  String? get bggUsername => throw _privateConstructorUsedError;

  /// Self only: whether the account has a password (false for accounts
  /// created with Google). Null when unknown.
  bool? get hasPassword => throw _privateConstructorUsedError;

  /// Self only: whether a Google account is linked. Null when unknown.
  bool? get googleLinked => throw _privateConstructorUsedError;
  bool get deleted => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call(
      {String id,
      String username,
      String? email,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      String? bio,
      String? location,
      bool onboardingCompleted,
      bool isAdmin,
      bool isVerified,
      String? preferredLanguage,
      String? timezone,
      DateTime? usernameChangeAvailableAt,
      String? bggUsername,
      bool? hasPassword,
      bool? googleLinked,
      bool deleted,
      DateTime? createdAt});
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? email = freezed,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? location = freezed,
    Object? onboardingCompleted = null,
    Object? isAdmin = null,
    Object? isVerified = null,
    Object? preferredLanguage = freezed,
    Object? timezone = freezed,
    Object? usernameChangeAvailableAt = freezed,
    Object? bggUsername = freezed,
    Object? hasPassword = freezed,
    Object? googleLinked = freezed,
    Object? deleted = null,
    Object? createdAt = freezed,
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
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      onboardingCompleted: null == onboardingCompleted
          ? _value.onboardingCompleted
          : onboardingCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isAdmin: null == isAdmin
          ? _value.isAdmin
          : isAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      preferredLanguage: freezed == preferredLanguage
          ? _value.preferredLanguage
          : preferredLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      usernameChangeAvailableAt: freezed == usernameChangeAvailableAt
          ? _value.usernameChangeAvailableAt
          : usernameChangeAvailableAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      bggUsername: freezed == bggUsername
          ? _value.bggUsername
          : bggUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      hasPassword: freezed == hasPassword
          ? _value.hasPassword
          : hasPassword // ignore: cast_nullable_to_non_nullable
              as bool?,
      googleLinked: freezed == googleLinked
          ? _value.googleLinked
          : googleLinked // ignore: cast_nullable_to_non_nullable
              as bool?,
      deleted: null == deleted
          ? _value.deleted
          : deleted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
          _$UserImpl value, $Res Function(_$UserImpl) then) =
      __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String? email,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      String? bio,
      String? location,
      bool onboardingCompleted,
      bool isAdmin,
      bool isVerified,
      String? preferredLanguage,
      String? timezone,
      DateTime? usernameChangeAvailableAt,
      String? bggUsername,
      bool? hasPassword,
      bool? googleLinked,
      bool deleted,
      DateTime? createdAt});
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
      : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? email = freezed,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? location = freezed,
    Object? onboardingCompleted = null,
    Object? isAdmin = null,
    Object? isVerified = null,
    Object? preferredLanguage = freezed,
    Object? timezone = freezed,
    Object? usernameChangeAvailableAt = freezed,
    Object? bggUsername = freezed,
    Object? hasPassword = freezed,
    Object? googleLinked = freezed,
    Object? deleted = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$UserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      onboardingCompleted: null == onboardingCompleted
          ? _value.onboardingCompleted
          : onboardingCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isAdmin: null == isAdmin
          ? _value.isAdmin
          : isAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      preferredLanguage: freezed == preferredLanguage
          ? _value.preferredLanguage
          : preferredLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      usernameChangeAvailableAt: freezed == usernameChangeAvailableAt
          ? _value.usernameChangeAvailableAt
          : usernameChangeAvailableAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      bggUsername: freezed == bggUsername
          ? _value.bggUsername
          : bggUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      hasPassword: freezed == hasPassword
          ? _value.hasPassword
          : hasPassword // ignore: cast_nullable_to_non_nullable
              as bool?,
      googleLinked: freezed == googleLinked
          ? _value.googleLinked
          : googleLinked // ignore: cast_nullable_to_non_nullable
              as bool?,
      deleted: null == deleted
          ? _value.deleted
          : deleted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl extends _User {
  const _$UserImpl(
      {required this.id,
      required this.username,
      this.email,
      @JsonKey(readValue: _readDisplayName) required this.displayName,
      this.avatarUrl,
      this.bio,
      this.location,
      this.onboardingCompleted = false,
      this.isAdmin = false,
      this.isVerified = false,
      this.preferredLanguage,
      this.timezone,
      this.usernameChangeAvailableAt,
      this.bggUsername,
      this.hasPassword,
      this.googleLinked,
      this.deleted = false,
      this.createdAt})
      : super._();

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final String id;
  @override
  final String username;
  @override
  final String? email;
  @override
  @JsonKey(readValue: _readDisplayName)
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  final String? bio;
  @override
  final String? location;
  @override
  @JsonKey()
  final bool onboardingCompleted;
  @override
  @JsonKey()
  final bool isAdmin;
  @override
  @JsonKey()
  final bool isVerified;

  /// `en` | `zh-CN`.
  @override
  final String? preferredLanguage;
  @override
  final String? timezone;
  @override
  final DateTime? usernameChangeAvailableAt;

  /// Self only (null on other users' profiles).
  @override
  final String? bggUsername;

  /// Self only: whether the account has a password (false for accounts
  /// created with Google). Null when unknown.
  @override
  final bool? hasPassword;

  /// Self only: whether a Google account is linked. Null when unknown.
  @override
  final bool? googleLinked;
  @override
  @JsonKey()
  final bool deleted;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, location: $location, onboardingCompleted: $onboardingCompleted, isAdmin: $isAdmin, isVerified: $isVerified, preferredLanguage: $preferredLanguage, timezone: $timezone, usernameChangeAvailableAt: $usernameChangeAvailableAt, bggUsername: $bggUsername, hasPassword: $hasPassword, googleLinked: $googleLinked, deleted: $deleted, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.onboardingCompleted, onboardingCompleted) ||
                other.onboardingCompleted == onboardingCompleted) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.preferredLanguage, preferredLanguage) ||
                other.preferredLanguage == preferredLanguage) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.usernameChangeAvailableAt,
                    usernameChangeAvailableAt) ||
                other.usernameChangeAvailableAt == usernameChangeAvailableAt) &&
            (identical(other.bggUsername, bggUsername) ||
                other.bggUsername == bggUsername) &&
            (identical(other.hasPassword, hasPassword) ||
                other.hasPassword == hasPassword) &&
            (identical(other.googleLinked, googleLinked) ||
                other.googleLinked == googleLinked) &&
            (identical(other.deleted, deleted) || other.deleted == deleted) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      username,
      email,
      displayName,
      avatarUrl,
      bio,
      location,
      onboardingCompleted,
      isAdmin,
      isVerified,
      preferredLanguage,
      timezone,
      usernameChangeAvailableAt,
      bggUsername,
      hasPassword,
      googleLinked,
      deleted,
      createdAt);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(
      this,
    );
  }
}

abstract class _User extends User {
  const factory _User(
      {required final String id,
      required final String username,
      final String? email,
      @JsonKey(readValue: _readDisplayName) required final String displayName,
      final String? avatarUrl,
      final String? bio,
      final String? location,
      final bool onboardingCompleted,
      final bool isAdmin,
      final bool isVerified,
      final String? preferredLanguage,
      final String? timezone,
      final DateTime? usernameChangeAvailableAt,
      final String? bggUsername,
      final bool? hasPassword,
      final bool? googleLinked,
      final bool deleted,
      final DateTime? createdAt}) = _$UserImpl;
  const _User._() : super._();

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  String get id;
  @override
  String get username;
  @override
  String? get email;
  @override
  @JsonKey(readValue: _readDisplayName)
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String? get bio;
  @override
  String? get location;
  @override
  bool get onboardingCompleted;
  @override
  bool get isAdmin;
  @override
  bool get isVerified;

  /// `en` | `zh-CN`.
  @override
  String? get preferredLanguage;
  @override
  String? get timezone;
  @override
  DateTime? get usernameChangeAvailableAt;

  /// Self only (null on other users' profiles).
  @override
  String? get bggUsername;

  /// Self only: whether the account has a password (false for accounts
  /// created with Google). Null when unknown.
  @override
  bool? get hasPassword;

  /// Self only: whether a Google account is linked. Null when unknown.
  @override
  bool? get googleLinked;
  @override
  bool get deleted;
  @override
  DateTime? get createdAt;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ActiveSession _$ActiveSessionFromJson(Map<String, dynamic> json) {
  return _ActiveSession.fromJson(json);
}

/// @nodoc
mixin _$ActiveSession {
  String get id => throw _privateConstructorUsedError;
  String? get deviceInfo => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;
  bool get current => throw _privateConstructorUsedError;

  /// Serializes this ActiveSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActiveSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActiveSessionCopyWith<ActiveSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActiveSessionCopyWith<$Res> {
  factory $ActiveSessionCopyWith(
          ActiveSession value, $Res Function(ActiveSession) then) =
      _$ActiveSessionCopyWithImpl<$Res, ActiveSession>;
  @useResult
  $Res call(
      {String id,
      String? deviceInfo,
      DateTime? createdAt,
      DateTime? lastUsedAt,
      bool current});
}

/// @nodoc
class _$ActiveSessionCopyWithImpl<$Res, $Val extends ActiveSession>
    implements $ActiveSessionCopyWith<$Res> {
  _$ActiveSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActiveSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceInfo = freezed,
    Object? createdAt = freezed,
    Object? lastUsedAt = freezed,
    Object? current = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      deviceInfo: freezed == deviceInfo
          ? _value.deviceInfo
          : deviceInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActiveSessionImplCopyWith<$Res>
    implements $ActiveSessionCopyWith<$Res> {
  factory _$$ActiveSessionImplCopyWith(
          _$ActiveSessionImpl value, $Res Function(_$ActiveSessionImpl) then) =
      __$$ActiveSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? deviceInfo,
      DateTime? createdAt,
      DateTime? lastUsedAt,
      bool current});
}

/// @nodoc
class __$$ActiveSessionImplCopyWithImpl<$Res>
    extends _$ActiveSessionCopyWithImpl<$Res, _$ActiveSessionImpl>
    implements _$$ActiveSessionImplCopyWith<$Res> {
  __$$ActiveSessionImplCopyWithImpl(
      _$ActiveSessionImpl _value, $Res Function(_$ActiveSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ActiveSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceInfo = freezed,
    Object? createdAt = freezed,
    Object? lastUsedAt = freezed,
    Object? current = null,
  }) {
    return _then(_$ActiveSessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      deviceInfo: freezed == deviceInfo
          ? _value.deviceInfo
          : deviceInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ActiveSessionImpl implements _ActiveSession {
  const _$ActiveSessionImpl(
      {required this.id,
      this.deviceInfo,
      this.createdAt,
      this.lastUsedAt,
      this.current = false});

  factory _$ActiveSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActiveSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String? deviceInfo;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? lastUsedAt;
  @override
  @JsonKey()
  final bool current;

  @override
  String toString() {
    return 'ActiveSession(id: $id, deviceInfo: $deviceInfo, createdAt: $createdAt, lastUsedAt: $lastUsedAt, current: $current)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActiveSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deviceInfo, deviceInfo) ||
                other.deviceInfo == deviceInfo) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt) &&
            (identical(other.current, current) || other.current == current));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, deviceInfo, createdAt, lastUsedAt, current);

  /// Create a copy of ActiveSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActiveSessionImplCopyWith<_$ActiveSessionImpl> get copyWith =>
      __$$ActiveSessionImplCopyWithImpl<_$ActiveSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActiveSessionImplToJson(
      this,
    );
  }
}

abstract class _ActiveSession implements ActiveSession {
  const factory _ActiveSession(
      {required final String id,
      final String? deviceInfo,
      final DateTime? createdAt,
      final DateTime? lastUsedAt,
      final bool current}) = _$ActiveSessionImpl;

  factory _ActiveSession.fromJson(Map<String, dynamic> json) =
      _$ActiveSessionImpl.fromJson;

  @override
  String get id;
  @override
  String? get deviceInfo;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get lastUsedAt;
  @override
  bool get current;

  /// Create a copy of ActiveSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActiveSessionImplCopyWith<_$ActiveSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
