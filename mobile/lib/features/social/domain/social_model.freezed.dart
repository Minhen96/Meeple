// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FriendRequest _$FriendRequestFromJson(Map<String, dynamic> json) {
  return _FriendRequest.fromJson(json);
}

/// @nodoc
mixin _$FriendRequest {
  String get id => throw _privateConstructorUsedError;
  UserSummary get sender => throw _privateConstructorUsedError;
  UserSummary get receiver => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this FriendRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendRequestCopyWith<FriendRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendRequestCopyWith<$Res> {
  factory $FriendRequestCopyWith(
          FriendRequest value, $Res Function(FriendRequest) then) =
      _$FriendRequestCopyWithImpl<$Res, FriendRequest>;
  @useResult
  $Res call(
      {String id,
      UserSummary sender,
      UserSummary receiver,
      String status,
      DateTime? createdAt});

  $UserSummaryCopyWith<$Res> get sender;
  $UserSummaryCopyWith<$Res> get receiver;
}

/// @nodoc
class _$FriendRequestCopyWithImpl<$Res, $Val extends FriendRequest>
    implements $FriendRequestCopyWith<$Res> {
  _$FriendRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? receiver = null,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      receiver: null == receiver
          ? _value.receiver
          : receiver // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserSummaryCopyWith<$Res> get sender {
    return $UserSummaryCopyWith<$Res>(_value.sender, (value) {
      return _then(_value.copyWith(sender: value) as $Val);
    });
  }

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserSummaryCopyWith<$Res> get receiver {
    return $UserSummaryCopyWith<$Res>(_value.receiver, (value) {
      return _then(_value.copyWith(receiver: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FriendRequestImplCopyWith<$Res>
    implements $FriendRequestCopyWith<$Res> {
  factory _$$FriendRequestImplCopyWith(
          _$FriendRequestImpl value, $Res Function(_$FriendRequestImpl) then) =
      __$$FriendRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      UserSummary sender,
      UserSummary receiver,
      String status,
      DateTime? createdAt});

  @override
  $UserSummaryCopyWith<$Res> get sender;
  @override
  $UserSummaryCopyWith<$Res> get receiver;
}

/// @nodoc
class __$$FriendRequestImplCopyWithImpl<$Res>
    extends _$FriendRequestCopyWithImpl<$Res, _$FriendRequestImpl>
    implements _$$FriendRequestImplCopyWith<$Res> {
  __$$FriendRequestImplCopyWithImpl(
      _$FriendRequestImpl _value, $Res Function(_$FriendRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? receiver = null,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$FriendRequestImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      receiver: null == receiver
          ? _value.receiver
          : receiver // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FriendRequestImpl implements _FriendRequest {
  const _$FriendRequestImpl(
      {required this.id,
      required this.sender,
      required this.receiver,
      this.status = 'PENDING',
      this.createdAt});

  factory _$FriendRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendRequestImplFromJson(json);

  @override
  final String id;
  @override
  final UserSummary sender;
  @override
  final UserSummary receiver;
  @override
  @JsonKey()
  final String status;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'FriendRequest(id: $id, sender: $sender, receiver: $receiver, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.receiver, receiver) ||
                other.receiver == receiver) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, sender, receiver, status, createdAt);

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendRequestImplCopyWith<_$FriendRequestImpl> get copyWith =>
      __$$FriendRequestImplCopyWithImpl<_$FriendRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendRequestImplToJson(
      this,
    );
  }
}

abstract class _FriendRequest implements FriendRequest {
  const factory _FriendRequest(
      {required final String id,
      required final UserSummary sender,
      required final UserSummary receiver,
      final String status,
      final DateTime? createdAt}) = _$FriendRequestImpl;

  factory _FriendRequest.fromJson(Map<String, dynamic> json) =
      _$FriendRequestImpl.fromJson;

  @override
  String get id;
  @override
  UserSummary get sender;
  @override
  UserSummary get receiver;
  @override
  String get status;
  @override
  DateTime? get createdAt;

  /// Create a copy of FriendRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendRequestImplCopyWith<_$FriendRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserStats _$UserStatsFromJson(Map<String, dynamic> json) {
  return _UserStats.fromJson(json);
}

/// @nodoc
mixin _$UserStats {
  int get gamesOwned => throw _privateConstructorUsedError;
  int get sessions => throw _privateConstructorUsedError;
  int get friends => throw _privateConstructorUsedError;
  MostPlayedGame? get mostPlayedGame => throw _privateConstructorUsedError;
  String? get favoriteCategory => throw _privateConstructorUsedError;
  MostPlayedWith? get mostPlayedWith => throw _privateConstructorUsedError;
  int get totalPlayMinutes => throw _privateConstructorUsedError;

  /// Serializes this UserStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserStatsCopyWith<UserStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserStatsCopyWith<$Res> {
  factory $UserStatsCopyWith(UserStats value, $Res Function(UserStats) then) =
      _$UserStatsCopyWithImpl<$Res, UserStats>;
  @useResult
  $Res call(
      {int gamesOwned,
      int sessions,
      int friends,
      MostPlayedGame? mostPlayedGame,
      String? favoriteCategory,
      MostPlayedWith? mostPlayedWith,
      int totalPlayMinutes});

  $MostPlayedGameCopyWith<$Res>? get mostPlayedGame;
  $MostPlayedWithCopyWith<$Res>? get mostPlayedWith;
}

/// @nodoc
class _$UserStatsCopyWithImpl<$Res, $Val extends UserStats>
    implements $UserStatsCopyWith<$Res> {
  _$UserStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gamesOwned = null,
    Object? sessions = null,
    Object? friends = null,
    Object? mostPlayedGame = freezed,
    Object? favoriteCategory = freezed,
    Object? mostPlayedWith = freezed,
    Object? totalPlayMinutes = null,
  }) {
    return _then(_value.copyWith(
      gamesOwned: null == gamesOwned
          ? _value.gamesOwned
          : gamesOwned // ignore: cast_nullable_to_non_nullable
              as int,
      sessions: null == sessions
          ? _value.sessions
          : sessions // ignore: cast_nullable_to_non_nullable
              as int,
      friends: null == friends
          ? _value.friends
          : friends // ignore: cast_nullable_to_non_nullable
              as int,
      mostPlayedGame: freezed == mostPlayedGame
          ? _value.mostPlayedGame
          : mostPlayedGame // ignore: cast_nullable_to_non_nullable
              as MostPlayedGame?,
      favoriteCategory: freezed == favoriteCategory
          ? _value.favoriteCategory
          : favoriteCategory // ignore: cast_nullable_to_non_nullable
              as String?,
      mostPlayedWith: freezed == mostPlayedWith
          ? _value.mostPlayedWith
          : mostPlayedWith // ignore: cast_nullable_to_non_nullable
              as MostPlayedWith?,
      totalPlayMinutes: null == totalPlayMinutes
          ? _value.totalPlayMinutes
          : totalPlayMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MostPlayedGameCopyWith<$Res>? get mostPlayedGame {
    if (_value.mostPlayedGame == null) {
      return null;
    }

    return $MostPlayedGameCopyWith<$Res>(_value.mostPlayedGame!, (value) {
      return _then(_value.copyWith(mostPlayedGame: value) as $Val);
    });
  }

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MostPlayedWithCopyWith<$Res>? get mostPlayedWith {
    if (_value.mostPlayedWith == null) {
      return null;
    }

    return $MostPlayedWithCopyWith<$Res>(_value.mostPlayedWith!, (value) {
      return _then(_value.copyWith(mostPlayedWith: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserStatsImplCopyWith<$Res>
    implements $UserStatsCopyWith<$Res> {
  factory _$$UserStatsImplCopyWith(
          _$UserStatsImpl value, $Res Function(_$UserStatsImpl) then) =
      __$$UserStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int gamesOwned,
      int sessions,
      int friends,
      MostPlayedGame? mostPlayedGame,
      String? favoriteCategory,
      MostPlayedWith? mostPlayedWith,
      int totalPlayMinutes});

  @override
  $MostPlayedGameCopyWith<$Res>? get mostPlayedGame;
  @override
  $MostPlayedWithCopyWith<$Res>? get mostPlayedWith;
}

/// @nodoc
class __$$UserStatsImplCopyWithImpl<$Res>
    extends _$UserStatsCopyWithImpl<$Res, _$UserStatsImpl>
    implements _$$UserStatsImplCopyWith<$Res> {
  __$$UserStatsImplCopyWithImpl(
      _$UserStatsImpl _value, $Res Function(_$UserStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gamesOwned = null,
    Object? sessions = null,
    Object? friends = null,
    Object? mostPlayedGame = freezed,
    Object? favoriteCategory = freezed,
    Object? mostPlayedWith = freezed,
    Object? totalPlayMinutes = null,
  }) {
    return _then(_$UserStatsImpl(
      gamesOwned: null == gamesOwned
          ? _value.gamesOwned
          : gamesOwned // ignore: cast_nullable_to_non_nullable
              as int,
      sessions: null == sessions
          ? _value.sessions
          : sessions // ignore: cast_nullable_to_non_nullable
              as int,
      friends: null == friends
          ? _value.friends
          : friends // ignore: cast_nullable_to_non_nullable
              as int,
      mostPlayedGame: freezed == mostPlayedGame
          ? _value.mostPlayedGame
          : mostPlayedGame // ignore: cast_nullable_to_non_nullable
              as MostPlayedGame?,
      favoriteCategory: freezed == favoriteCategory
          ? _value.favoriteCategory
          : favoriteCategory // ignore: cast_nullable_to_non_nullable
              as String?,
      mostPlayedWith: freezed == mostPlayedWith
          ? _value.mostPlayedWith
          : mostPlayedWith // ignore: cast_nullable_to_non_nullable
              as MostPlayedWith?,
      totalPlayMinutes: null == totalPlayMinutes
          ? _value.totalPlayMinutes
          : totalPlayMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserStatsImpl implements _UserStats {
  const _$UserStatsImpl(
      {this.gamesOwned = 0,
      this.sessions = 0,
      this.friends = 0,
      this.mostPlayedGame,
      this.favoriteCategory,
      this.mostPlayedWith,
      this.totalPlayMinutes = 0});

  factory _$UserStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserStatsImplFromJson(json);

  @override
  @JsonKey()
  final int gamesOwned;
  @override
  @JsonKey()
  final int sessions;
  @override
  @JsonKey()
  final int friends;
  @override
  final MostPlayedGame? mostPlayedGame;
  @override
  final String? favoriteCategory;
  @override
  final MostPlayedWith? mostPlayedWith;
  @override
  @JsonKey()
  final int totalPlayMinutes;

  @override
  String toString() {
    return 'UserStats(gamesOwned: $gamesOwned, sessions: $sessions, friends: $friends, mostPlayedGame: $mostPlayedGame, favoriteCategory: $favoriteCategory, mostPlayedWith: $mostPlayedWith, totalPlayMinutes: $totalPlayMinutes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserStatsImpl &&
            (identical(other.gamesOwned, gamesOwned) ||
                other.gamesOwned == gamesOwned) &&
            (identical(other.sessions, sessions) ||
                other.sessions == sessions) &&
            (identical(other.friends, friends) || other.friends == friends) &&
            (identical(other.mostPlayedGame, mostPlayedGame) ||
                other.mostPlayedGame == mostPlayedGame) &&
            (identical(other.favoriteCategory, favoriteCategory) ||
                other.favoriteCategory == favoriteCategory) &&
            (identical(other.mostPlayedWith, mostPlayedWith) ||
                other.mostPlayedWith == mostPlayedWith) &&
            (identical(other.totalPlayMinutes, totalPlayMinutes) ||
                other.totalPlayMinutes == totalPlayMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, gamesOwned, sessions, friends,
      mostPlayedGame, favoriteCategory, mostPlayedWith, totalPlayMinutes);

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      __$$UserStatsImplCopyWithImpl<_$UserStatsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserStatsImplToJson(
      this,
    );
  }
}

abstract class _UserStats implements UserStats {
  const factory _UserStats(
      {final int gamesOwned,
      final int sessions,
      final int friends,
      final MostPlayedGame? mostPlayedGame,
      final String? favoriteCategory,
      final MostPlayedWith? mostPlayedWith,
      final int totalPlayMinutes}) = _$UserStatsImpl;

  factory _UserStats.fromJson(Map<String, dynamic> json) =
      _$UserStatsImpl.fromJson;

  @override
  int get gamesOwned;
  @override
  int get sessions;
  @override
  int get friends;
  @override
  MostPlayedGame? get mostPlayedGame;
  @override
  String? get favoriteCategory;
  @override
  MostPlayedWith? get mostPlayedWith;
  @override
  int get totalPlayMinutes;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MostPlayedGame _$MostPlayedGameFromJson(Map<String, dynamic> json) {
  return _MostPlayedGame.fromJson(json);
}

/// @nodoc
mixin _$MostPlayedGame {
  String get gameId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get playCount => throw _privateConstructorUsedError;

  /// Serializes this MostPlayedGame to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MostPlayedGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MostPlayedGameCopyWith<MostPlayedGame> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MostPlayedGameCopyWith<$Res> {
  factory $MostPlayedGameCopyWith(
          MostPlayedGame value, $Res Function(MostPlayedGame) then) =
      _$MostPlayedGameCopyWithImpl<$Res, MostPlayedGame>;
  @useResult
  $Res call({String gameId, String title, int playCount});
}

/// @nodoc
class _$MostPlayedGameCopyWithImpl<$Res, $Val extends MostPlayedGame>
    implements $MostPlayedGameCopyWith<$Res> {
  _$MostPlayedGameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MostPlayedGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? title = null,
    Object? playCount = null,
  }) {
    return _then(_value.copyWith(
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MostPlayedGameImplCopyWith<$Res>
    implements $MostPlayedGameCopyWith<$Res> {
  factory _$$MostPlayedGameImplCopyWith(_$MostPlayedGameImpl value,
          $Res Function(_$MostPlayedGameImpl) then) =
      __$$MostPlayedGameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String gameId, String title, int playCount});
}

/// @nodoc
class __$$MostPlayedGameImplCopyWithImpl<$Res>
    extends _$MostPlayedGameCopyWithImpl<$Res, _$MostPlayedGameImpl>
    implements _$$MostPlayedGameImplCopyWith<$Res> {
  __$$MostPlayedGameImplCopyWithImpl(
      _$MostPlayedGameImpl _value, $Res Function(_$MostPlayedGameImpl) _then)
      : super(_value, _then);

  /// Create a copy of MostPlayedGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? title = null,
    Object? playCount = null,
  }) {
    return _then(_$MostPlayedGameImpl(
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MostPlayedGameImpl implements _MostPlayedGame {
  const _$MostPlayedGameImpl(
      {required this.gameId, this.title = '', this.playCount = 0});

  factory _$MostPlayedGameImpl.fromJson(Map<String, dynamic> json) =>
      _$$MostPlayedGameImplFromJson(json);

  @override
  final String gameId;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey()
  final int playCount;

  @override
  String toString() {
    return 'MostPlayedGame(gameId: $gameId, title: $title, playCount: $playCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MostPlayedGameImpl &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.playCount, playCount) ||
                other.playCount == playCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, gameId, title, playCount);

  /// Create a copy of MostPlayedGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MostPlayedGameImplCopyWith<_$MostPlayedGameImpl> get copyWith =>
      __$$MostPlayedGameImplCopyWithImpl<_$MostPlayedGameImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MostPlayedGameImplToJson(
      this,
    );
  }
}

abstract class _MostPlayedGame implements MostPlayedGame {
  const factory _MostPlayedGame(
      {required final String gameId,
      final String title,
      final int playCount}) = _$MostPlayedGameImpl;

  factory _MostPlayedGame.fromJson(Map<String, dynamic> json) =
      _$MostPlayedGameImpl.fromJson;

  @override
  String get gameId;
  @override
  String get title;
  @override
  int get playCount;

  /// Create a copy of MostPlayedGame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MostPlayedGameImplCopyWith<_$MostPlayedGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MostPlayedWith _$MostPlayedWithFromJson(Map<String, dynamic> json) {
  return _MostPlayedWith.fromJson(json);
}

/// @nodoc
mixin _$MostPlayedWith {
  String get userId => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  int get sharedSessions => throw _privateConstructorUsedError;

  /// Serializes this MostPlayedWith to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MostPlayedWith
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MostPlayedWithCopyWith<MostPlayedWith> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MostPlayedWithCopyWith<$Res> {
  factory $MostPlayedWithCopyWith(
          MostPlayedWith value, $Res Function(MostPlayedWith) then) =
      _$MostPlayedWithCopyWithImpl<$Res, MostPlayedWith>;
  @useResult
  $Res call({String userId, String displayName, int sharedSessions});
}

/// @nodoc
class _$MostPlayedWithCopyWithImpl<$Res, $Val extends MostPlayedWith>
    implements $MostPlayedWithCopyWith<$Res> {
  _$MostPlayedWithCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MostPlayedWith
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? displayName = null,
    Object? sharedSessions = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      sharedSessions: null == sharedSessions
          ? _value.sharedSessions
          : sharedSessions // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MostPlayedWithImplCopyWith<$Res>
    implements $MostPlayedWithCopyWith<$Res> {
  factory _$$MostPlayedWithImplCopyWith(_$MostPlayedWithImpl value,
          $Res Function(_$MostPlayedWithImpl) then) =
      __$$MostPlayedWithImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String userId, String displayName, int sharedSessions});
}

/// @nodoc
class __$$MostPlayedWithImplCopyWithImpl<$Res>
    extends _$MostPlayedWithCopyWithImpl<$Res, _$MostPlayedWithImpl>
    implements _$$MostPlayedWithImplCopyWith<$Res> {
  __$$MostPlayedWithImplCopyWithImpl(
      _$MostPlayedWithImpl _value, $Res Function(_$MostPlayedWithImpl) _then)
      : super(_value, _then);

  /// Create a copy of MostPlayedWith
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? displayName = null,
    Object? sharedSessions = null,
  }) {
    return _then(_$MostPlayedWithImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      sharedSessions: null == sharedSessions
          ? _value.sharedSessions
          : sharedSessions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MostPlayedWithImpl implements _MostPlayedWith {
  const _$MostPlayedWithImpl(
      {required this.userId, this.displayName = '', this.sharedSessions = 0});

  factory _$MostPlayedWithImpl.fromJson(Map<String, dynamic> json) =>
      _$$MostPlayedWithImplFromJson(json);

  @override
  final String userId;
  @override
  @JsonKey()
  final String displayName;
  @override
  @JsonKey()
  final int sharedSessions;

  @override
  String toString() {
    return 'MostPlayedWith(userId: $userId, displayName: $displayName, sharedSessions: $sharedSessions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MostPlayedWithImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.sharedSessions, sharedSessions) ||
                other.sharedSessions == sharedSessions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, displayName, sharedSessions);

  /// Create a copy of MostPlayedWith
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MostPlayedWithImplCopyWith<_$MostPlayedWithImpl> get copyWith =>
      __$$MostPlayedWithImplCopyWithImpl<_$MostPlayedWithImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MostPlayedWithImplToJson(
      this,
    );
  }
}

abstract class _MostPlayedWith implements MostPlayedWith {
  const factory _MostPlayedWith(
      {required final String userId,
      final String displayName,
      final int sharedSessions}) = _$MostPlayedWithImpl;

  factory _MostPlayedWith.fromJson(Map<String, dynamic> json) =
      _$MostPlayedWithImpl.fromJson;

  @override
  String get userId;
  @override
  String get displayName;
  @override
  int get sharedSessions;

  /// Create a copy of MostPlayedWith
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MostPlayedWithImplCopyWith<_$MostPlayedWithImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
