// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_game_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserGame _$UserGameFromJson(Map<String, dynamic> json) {
  return _UserGame.fromJson(json);
}

/// @nodoc
mixin _$UserGame {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readGameId)
  String get gameId => throw _privateConstructorUsedError;
  Game get game => throw _privateConstructorUsedError;
  bool get isOwned => throw _privateConstructorUsedError;
  bool get isWishlisted => throw _privateConstructorUsedError;
  bool get isFavorited => throw _privateConstructorUsedError;
  int get playCount => throw _privateConstructorUsedError;
  double? get personalRating => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this UserGame to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserGameCopyWith<UserGame> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserGameCopyWith<$Res> {
  factory $UserGameCopyWith(UserGame value, $Res Function(UserGame) then) =
      _$UserGameCopyWithImpl<$Res, UserGame>;
  @useResult
  $Res call(
      {String? id,
      @JsonKey(readValue: _readGameId) String gameId,
      Game game,
      bool isOwned,
      bool isWishlisted,
      bool isFavorited,
      int playCount,
      double? personalRating,
      String? notes});

  $GameCopyWith<$Res> get game;
}

/// @nodoc
class _$UserGameCopyWithImpl<$Res, $Val extends UserGame>
    implements $UserGameCopyWith<$Res> {
  _$UserGameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? gameId = null,
    Object? game = null,
    Object? isOwned = null,
    Object? isWishlisted = null,
    Object? isFavorited = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      isOwned: null == isOwned
          ? _value.isOwned
          : isOwned // ignore: cast_nullable_to_non_nullable
              as bool,
      isWishlisted: null == isWishlisted
          ? _value.isWishlisted
          : isWishlisted // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameCopyWith<$Res> get game {
    return $GameCopyWith<$Res>(_value.game, (value) {
      return _then(_value.copyWith(game: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserGameImplCopyWith<$Res>
    implements $UserGameCopyWith<$Res> {
  factory _$$UserGameImplCopyWith(
          _$UserGameImpl value, $Res Function(_$UserGameImpl) then) =
      __$$UserGameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      @JsonKey(readValue: _readGameId) String gameId,
      Game game,
      bool isOwned,
      bool isWishlisted,
      bool isFavorited,
      int playCount,
      double? personalRating,
      String? notes});

  @override
  $GameCopyWith<$Res> get game;
}

/// @nodoc
class __$$UserGameImplCopyWithImpl<$Res>
    extends _$UserGameCopyWithImpl<$Res, _$UserGameImpl>
    implements _$$UserGameImplCopyWith<$Res> {
  __$$UserGameImplCopyWithImpl(
      _$UserGameImpl _value, $Res Function(_$UserGameImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? gameId = null,
    Object? game = null,
    Object? isOwned = null,
    Object? isWishlisted = null,
    Object? isFavorited = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$UserGameImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      isOwned: null == isOwned
          ? _value.isOwned
          : isOwned // ignore: cast_nullable_to_non_nullable
              as bool,
      isWishlisted: null == isWishlisted
          ? _value.isWishlisted
          : isWishlisted // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserGameImpl extends _UserGame {
  const _$UserGameImpl(
      {this.id,
      @JsonKey(readValue: _readGameId) required this.gameId,
      required this.game,
      this.isOwned = false,
      this.isWishlisted = false,
      this.isFavorited = false,
      this.playCount = 0,
      this.personalRating,
      this.notes})
      : super._();

  factory _$UserGameImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserGameImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(readValue: _readGameId)
  final String gameId;
  @override
  final Game game;
  @override
  @JsonKey()
  final bool isOwned;
  @override
  @JsonKey()
  final bool isWishlisted;
  @override
  @JsonKey()
  final bool isFavorited;
  @override
  @JsonKey()
  final int playCount;
  @override
  final double? personalRating;
  @override
  final String? notes;

  @override
  String toString() {
    return 'UserGame(id: $id, gameId: $gameId, game: $game, isOwned: $isOwned, isWishlisted: $isWishlisted, isFavorited: $isFavorited, playCount: $playCount, personalRating: $personalRating, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserGameImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.game, game) || other.game == game) &&
            (identical(other.isOwned, isOwned) || other.isOwned == isOwned) &&
            (identical(other.isWishlisted, isWishlisted) ||
                other.isWishlisted == isWishlisted) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.playCount, playCount) ||
                other.playCount == playCount) &&
            (identical(other.personalRating, personalRating) ||
                other.personalRating == personalRating) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, gameId, game, isOwned,
      isWishlisted, isFavorited, playCount, personalRating, notes);

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserGameImplCopyWith<_$UserGameImpl> get copyWith =>
      __$$UserGameImplCopyWithImpl<_$UserGameImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserGameImplToJson(
      this,
    );
  }
}

abstract class _UserGame extends UserGame {
  const factory _UserGame(
      {final String? id,
      @JsonKey(readValue: _readGameId) required final String gameId,
      required final Game game,
      final bool isOwned,
      final bool isWishlisted,
      final bool isFavorited,
      final int playCount,
      final double? personalRating,
      final String? notes}) = _$UserGameImpl;
  const _UserGame._() : super._();

  factory _UserGame.fromJson(Map<String, dynamic> json) =
      _$UserGameImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(readValue: _readGameId)
  String get gameId;
  @override
  Game get game;
  @override
  bool get isOwned;
  @override
  bool get isWishlisted;
  @override
  bool get isFavorited;
  @override
  int get playCount;
  @override
  double? get personalRating;
  @override
  String? get notes;

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserGameImplCopyWith<_$UserGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayLog _$PlayLogFromJson(Map<String, dynamic> json) {
  return _PlayLog.fromJson(json);
}

/// @nodoc
mixin _$PlayLog {
  String get id => throw _privateConstructorUsedError;
  DateTime get playedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  int? get durationMinutes => throw _privateConstructorUsedError;
  int? get playerCount => throw _privateConstructorUsedError;

  /// Serializes this PlayLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayLogCopyWith<PlayLog> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayLogCopyWith<$Res> {
  factory $PlayLogCopyWith(PlayLog value, $Res Function(PlayLog) then) =
      _$PlayLogCopyWithImpl<$Res, PlayLog>;
  @useResult
  $Res call(
      {String id,
      DateTime playedAt,
      String? notes,
      int? durationMinutes,
      int? playerCount});
}

/// @nodoc
class _$PlayLogCopyWithImpl<$Res, $Val extends PlayLog>
    implements $PlayLogCopyWith<$Res> {
  _$PlayLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? playedAt = null,
    Object? notes = freezed,
    Object? durationMinutes = freezed,
    Object? playerCount = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      playedAt: null == playedAt
          ? _value.playedAt
          : playedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMinutes: freezed == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      playerCount: freezed == playerCount
          ? _value.playerCount
          : playerCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlayLogImplCopyWith<$Res> implements $PlayLogCopyWith<$Res> {
  factory _$$PlayLogImplCopyWith(
          _$PlayLogImpl value, $Res Function(_$PlayLogImpl) then) =
      __$$PlayLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime playedAt,
      String? notes,
      int? durationMinutes,
      int? playerCount});
}

/// @nodoc
class __$$PlayLogImplCopyWithImpl<$Res>
    extends _$PlayLogCopyWithImpl<$Res, _$PlayLogImpl>
    implements _$$PlayLogImplCopyWith<$Res> {
  __$$PlayLogImplCopyWithImpl(
      _$PlayLogImpl _value, $Res Function(_$PlayLogImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlayLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? playedAt = null,
    Object? notes = freezed,
    Object? durationMinutes = freezed,
    Object? playerCount = freezed,
  }) {
    return _then(_$PlayLogImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      playedAt: null == playedAt
          ? _value.playedAt
          : playedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMinutes: freezed == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      playerCount: freezed == playerCount
          ? _value.playerCount
          : playerCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayLogImpl implements _PlayLog {
  const _$PlayLogImpl(
      {required this.id,
      required this.playedAt,
      this.notes,
      this.durationMinutes,
      this.playerCount});

  factory _$PlayLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayLogImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime playedAt;
  @override
  final String? notes;
  @override
  final int? durationMinutes;
  @override
  final int? playerCount;

  @override
  String toString() {
    return 'PlayLog(id: $id, playedAt: $playedAt, notes: $notes, durationMinutes: $durationMinutes, playerCount: $playerCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.playedAt, playedAt) ||
                other.playedAt == playedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            (identical(other.playerCount, playerCount) ||
                other.playerCount == playerCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, playedAt, notes, durationMinutes, playerCount);

  /// Create a copy of PlayLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayLogImplCopyWith<_$PlayLogImpl> get copyWith =>
      __$$PlayLogImplCopyWithImpl<_$PlayLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayLogImplToJson(
      this,
    );
  }
}

abstract class _PlayLog implements PlayLog {
  const factory _PlayLog(
      {required final String id,
      required final DateTime playedAt,
      final String? notes,
      final int? durationMinutes,
      final int? playerCount}) = _$PlayLogImpl;

  factory _PlayLog.fromJson(Map<String, dynamic> json) = _$PlayLogImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get playedAt;
  @override
  String? get notes;
  @override
  int? get durationMinutes;
  @override
  int? get playerCount;

  /// Create a copy of PlayLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayLogImplCopyWith<_$PlayLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FriendGameEntry _$FriendGameEntryFromJson(Map<String, dynamic> json) {
  return _FriendGameEntry.fromJson(json);
}

/// @nodoc
mixin _$FriendGameEntry {
  UserSummary get user => throw _privateConstructorUsedError;
  int get playCount => throw _privateConstructorUsedError;
  double? get personalRating => throw _privateConstructorUsedError;
  bool get isOwned => throw _privateConstructorUsedError;

  /// Serializes this FriendGameEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendGameEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendGameEntryCopyWith<FriendGameEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendGameEntryCopyWith<$Res> {
  factory $FriendGameEntryCopyWith(
          FriendGameEntry value, $Res Function(FriendGameEntry) then) =
      _$FriendGameEntryCopyWithImpl<$Res, FriendGameEntry>;
  @useResult
  $Res call(
      {UserSummary user, int playCount, double? personalRating, bool isOwned});

  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class _$FriendGameEntryCopyWithImpl<$Res, $Val extends FriendGameEntry>
    implements $FriendGameEntryCopyWith<$Res> {
  _$FriendGameEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendGameEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? isOwned = null,
  }) {
    return _then(_value.copyWith(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      isOwned: null == isOwned
          ? _value.isOwned
          : isOwned // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of FriendGameEntry
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
abstract class _$$FriendGameEntryImplCopyWith<$Res>
    implements $FriendGameEntryCopyWith<$Res> {
  factory _$$FriendGameEntryImplCopyWith(_$FriendGameEntryImpl value,
          $Res Function(_$FriendGameEntryImpl) then) =
      __$$FriendGameEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {UserSummary user, int playCount, double? personalRating, bool isOwned});

  @override
  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class __$$FriendGameEntryImplCopyWithImpl<$Res>
    extends _$FriendGameEntryCopyWithImpl<$Res, _$FriendGameEntryImpl>
    implements _$$FriendGameEntryImplCopyWith<$Res> {
  __$$FriendGameEntryImplCopyWithImpl(
      _$FriendGameEntryImpl _value, $Res Function(_$FriendGameEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of FriendGameEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? isOwned = null,
  }) {
    return _then(_$FriendGameEntryImpl(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      isOwned: null == isOwned
          ? _value.isOwned
          : isOwned // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FriendGameEntryImpl implements _FriendGameEntry {
  const _$FriendGameEntryImpl(
      {required this.user,
      this.playCount = 0,
      this.personalRating,
      this.isOwned = false});

  factory _$FriendGameEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendGameEntryImplFromJson(json);

  @override
  final UserSummary user;
  @override
  @JsonKey()
  final int playCount;
  @override
  final double? personalRating;
  @override
  @JsonKey()
  final bool isOwned;

  @override
  String toString() {
    return 'FriendGameEntry(user: $user, playCount: $playCount, personalRating: $personalRating, isOwned: $isOwned)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendGameEntryImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.playCount, playCount) ||
                other.playCount == playCount) &&
            (identical(other.personalRating, personalRating) ||
                other.personalRating == personalRating) &&
            (identical(other.isOwned, isOwned) || other.isOwned == isOwned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, user, playCount, personalRating, isOwned);

  /// Create a copy of FriendGameEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendGameEntryImplCopyWith<_$FriendGameEntryImpl> get copyWith =>
      __$$FriendGameEntryImplCopyWithImpl<_$FriendGameEntryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendGameEntryImplToJson(
      this,
    );
  }
}

abstract class _FriendGameEntry implements FriendGameEntry {
  const factory _FriendGameEntry(
      {required final UserSummary user,
      final int playCount,
      final double? personalRating,
      final bool isOwned}) = _$FriendGameEntryImpl;

  factory _FriendGameEntry.fromJson(Map<String, dynamic> json) =
      _$FriendGameEntryImpl.fromJson;

  @override
  UserSummary get user;
  @override
  int get playCount;
  @override
  double? get personalRating;
  @override
  bool get isOwned;

  /// Create a copy of FriendGameEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendGameEntryImplCopyWith<_$FriendGameEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GameReview _$GameReviewFromJson(Map<String, dynamic> json) {
  return _GameReview.fromJson(json);
}

/// @nodoc
mixin _$GameReview {
  UserSummary get user => throw _privateConstructorUsedError;
  double? get personalRating => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  int get playCount => throw _privateConstructorUsedError;

  /// Serializes this GameReview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameReviewCopyWith<GameReview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameReviewCopyWith<$Res> {
  factory $GameReviewCopyWith(
          GameReview value, $Res Function(GameReview) then) =
      _$GameReviewCopyWithImpl<$Res, GameReview>;
  @useResult
  $Res call(
      {UserSummary user, double? personalRating, String? notes, int playCount});

  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class _$GameReviewCopyWithImpl<$Res, $Val extends GameReview>
    implements $GameReviewCopyWith<$Res> {
  _$GameReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
    Object? playCount = null,
  }) {
    return _then(_value.copyWith(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of GameReview
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
abstract class _$$GameReviewImplCopyWith<$Res>
    implements $GameReviewCopyWith<$Res> {
  factory _$$GameReviewImplCopyWith(
          _$GameReviewImpl value, $Res Function(_$GameReviewImpl) then) =
      __$$GameReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {UserSummary user, double? personalRating, String? notes, int playCount});

  @override
  $UserSummaryCopyWith<$Res> get user;
}

/// @nodoc
class __$$GameReviewImplCopyWithImpl<$Res>
    extends _$GameReviewCopyWithImpl<$Res, _$GameReviewImpl>
    implements _$$GameReviewImplCopyWith<$Res> {
  __$$GameReviewImplCopyWithImpl(
      _$GameReviewImpl _value, $Res Function(_$GameReviewImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
    Object? playCount = null,
  }) {
    return _then(_$GameReviewImpl(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserSummary,
      personalRating: freezed == personalRating
          ? _value.personalRating
          : personalRating // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      playCount: null == playCount
          ? _value.playCount
          : playCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameReviewImpl implements _GameReview {
  const _$GameReviewImpl(
      {required this.user,
      this.personalRating,
      this.notes,
      this.playCount = 0});

  factory _$GameReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameReviewImplFromJson(json);

  @override
  final UserSummary user;
  @override
  final double? personalRating;
  @override
  final String? notes;
  @override
  @JsonKey()
  final int playCount;

  @override
  String toString() {
    return 'GameReview(user: $user, personalRating: $personalRating, notes: $notes, playCount: $playCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameReviewImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.personalRating, personalRating) ||
                other.personalRating == personalRating) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.playCount, playCount) ||
                other.playCount == playCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, user, personalRating, notes, playCount);

  /// Create a copy of GameReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameReviewImplCopyWith<_$GameReviewImpl> get copyWith =>
      __$$GameReviewImplCopyWithImpl<_$GameReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameReviewImplToJson(
      this,
    );
  }
}

abstract class _GameReview implements GameReview {
  const factory _GameReview(
      {required final UserSummary user,
      final double? personalRating,
      final String? notes,
      final int playCount}) = _$GameReviewImpl;

  factory _GameReview.fromJson(Map<String, dynamic> json) =
      _$GameReviewImpl.fromJson;

  @override
  UserSummary get user;
  @override
  double? get personalRating;
  @override
  String? get notes;
  @override
  int get playCount;

  /// Create a copy of GameReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameReviewImplCopyWith<_$GameReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HowToPlay _$HowToPlayFromJson(Map<String, dynamic> json) {
  return _HowToPlay.fromJson(json);
}

/// @nodoc
mixin _$HowToPlay {
  /// `ready` | `generating` | `not_generated` | `failed`.
  String get status => throw _privateConstructorUsedError;
  Map<String, dynamic>? get data => throw _privateConstructorUsedError;
  String? get sourceMode => throw _privateConstructorUsedError;
  String? get disclaimer => throw _privateConstructorUsedError;
  String? get rulebookUrl => throw _privateConstructorUsedError;
  int? get progress => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Serializes this HowToPlay to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HowToPlay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HowToPlayCopyWith<HowToPlay> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HowToPlayCopyWith<$Res> {
  factory $HowToPlayCopyWith(HowToPlay value, $Res Function(HowToPlay) then) =
      _$HowToPlayCopyWithImpl<$Res, HowToPlay>;
  @useResult
  $Res call(
      {String status,
      Map<String, dynamic>? data,
      String? sourceMode,
      String? disclaimer,
      String? rulebookUrl,
      int? progress,
      String? errorMessage});
}

/// @nodoc
class _$HowToPlayCopyWithImpl<$Res, $Val extends HowToPlay>
    implements $HowToPlayCopyWith<$Res> {
  _$HowToPlayCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HowToPlay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? data = freezed,
    Object? sourceMode = freezed,
    Object? disclaimer = freezed,
    Object? rulebookUrl = freezed,
    Object? progress = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sourceMode: freezed == sourceMode
          ? _value.sourceMode
          : sourceMode // ignore: cast_nullable_to_non_nullable
              as String?,
      disclaimer: freezed == disclaimer
          ? _value.disclaimer
          : disclaimer // ignore: cast_nullable_to_non_nullable
              as String?,
      rulebookUrl: freezed == rulebookUrl
          ? _value.rulebookUrl
          : rulebookUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: freezed == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HowToPlayImplCopyWith<$Res>
    implements $HowToPlayCopyWith<$Res> {
  factory _$$HowToPlayImplCopyWith(
          _$HowToPlayImpl value, $Res Function(_$HowToPlayImpl) then) =
      __$$HowToPlayImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String status,
      Map<String, dynamic>? data,
      String? sourceMode,
      String? disclaimer,
      String? rulebookUrl,
      int? progress,
      String? errorMessage});
}

/// @nodoc
class __$$HowToPlayImplCopyWithImpl<$Res>
    extends _$HowToPlayCopyWithImpl<$Res, _$HowToPlayImpl>
    implements _$$HowToPlayImplCopyWith<$Res> {
  __$$HowToPlayImplCopyWithImpl(
      _$HowToPlayImpl _value, $Res Function(_$HowToPlayImpl) _then)
      : super(_value, _then);

  /// Create a copy of HowToPlay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? data = freezed,
    Object? sourceMode = freezed,
    Object? disclaimer = freezed,
    Object? rulebookUrl = freezed,
    Object? progress = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(_$HowToPlayImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      data: freezed == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sourceMode: freezed == sourceMode
          ? _value.sourceMode
          : sourceMode // ignore: cast_nullable_to_non_nullable
              as String?,
      disclaimer: freezed == disclaimer
          ? _value.disclaimer
          : disclaimer // ignore: cast_nullable_to_non_nullable
              as String?,
      rulebookUrl: freezed == rulebookUrl
          ? _value.rulebookUrl
          : rulebookUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: freezed == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HowToPlayImpl implements _HowToPlay {
  const _$HowToPlayImpl(
      {required this.status,
      final Map<String, dynamic>? data,
      this.sourceMode,
      this.disclaimer,
      this.rulebookUrl,
      this.progress,
      this.errorMessage})
      : _data = data;

  factory _$HowToPlayImpl.fromJson(Map<String, dynamic> json) =>
      _$$HowToPlayImplFromJson(json);

  /// `ready` | `generating` | `not_generated` | `failed`.
  @override
  final String status;
  final Map<String, dynamic>? _data;
  @override
  Map<String, dynamic>? get data {
    final value = _data;
    if (value == null) return null;
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? sourceMode;
  @override
  final String? disclaimer;
  @override
  final String? rulebookUrl;
  @override
  final int? progress;
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'HowToPlay(status: $status, data: $data, sourceMode: $sourceMode, disclaimer: $disclaimer, rulebookUrl: $rulebookUrl, progress: $progress, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HowToPlayImpl &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.sourceMode, sourceMode) ||
                other.sourceMode == sourceMode) &&
            (identical(other.disclaimer, disclaimer) ||
                other.disclaimer == disclaimer) &&
            (identical(other.rulebookUrl, rulebookUrl) ||
                other.rulebookUrl == rulebookUrl) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_data),
      sourceMode,
      disclaimer,
      rulebookUrl,
      progress,
      errorMessage);

  /// Create a copy of HowToPlay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HowToPlayImplCopyWith<_$HowToPlayImpl> get copyWith =>
      __$$HowToPlayImplCopyWithImpl<_$HowToPlayImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HowToPlayImplToJson(
      this,
    );
  }
}

abstract class _HowToPlay implements HowToPlay {
  const factory _HowToPlay(
      {required final String status,
      final Map<String, dynamic>? data,
      final String? sourceMode,
      final String? disclaimer,
      final String? rulebookUrl,
      final int? progress,
      final String? errorMessage}) = _$HowToPlayImpl;

  factory _HowToPlay.fromJson(Map<String, dynamic> json) =
      _$HowToPlayImpl.fromJson;

  /// `ready` | `generating` | `not_generated` | `failed`.
  @override
  String get status;
  @override
  Map<String, dynamic>? get data;
  @override
  String? get sourceMode;
  @override
  String? get disclaimer;
  @override
  String? get rulebookUrl;
  @override
  int? get progress;
  @override
  String? get errorMessage;

  /// Create a copy of HowToPlay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HowToPlayImplCopyWith<_$HowToPlayImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BggImportStatus _$BggImportStatusFromJson(Map<String, dynamic> json) {
  return _BggImportStatus.fromJson(json);
}

/// @nodoc
mixin _$BggImportStatus {
  /// `idle` | `running` | `done` | `failed`.
  String get status => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get processed => throw _privateConstructorUsedError;
  int get imported => throw _privateConstructorUsedError;
  int get skipped => throw _privateConstructorUsedError;
  int get failed => throw _privateConstructorUsedError;
  String? get errorCode => throw _privateConstructorUsedError;

  /// First imported games (`{gameId, title, thumbnailUrl}`) for the
  /// success preview row.
  List<BggPreviewGame> get preview => throw _privateConstructorUsedError;

  /// Serializes this BggImportStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BggImportStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BggImportStatusCopyWith<BggImportStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BggImportStatusCopyWith<$Res> {
  factory $BggImportStatusCopyWith(
          BggImportStatus value, $Res Function(BggImportStatus) then) =
      _$BggImportStatusCopyWithImpl<$Res, BggImportStatus>;
  @useResult
  $Res call(
      {String status,
      int total,
      int processed,
      int imported,
      int skipped,
      int failed,
      String? errorCode,
      List<BggPreviewGame> preview});
}

/// @nodoc
class _$BggImportStatusCopyWithImpl<$Res, $Val extends BggImportStatus>
    implements $BggImportStatusCopyWith<$Res> {
  _$BggImportStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BggImportStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? total = null,
    Object? processed = null,
    Object? imported = null,
    Object? skipped = null,
    Object? failed = null,
    Object? errorCode = freezed,
    Object? preview = null,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      processed: null == processed
          ? _value.processed
          : processed // ignore: cast_nullable_to_non_nullable
              as int,
      imported: null == imported
          ? _value.imported
          : imported // ignore: cast_nullable_to_non_nullable
              as int,
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as int,
      failed: null == failed
          ? _value.failed
          : failed // ignore: cast_nullable_to_non_nullable
              as int,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      preview: null == preview
          ? _value.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as List<BggPreviewGame>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BggImportStatusImplCopyWith<$Res>
    implements $BggImportStatusCopyWith<$Res> {
  factory _$$BggImportStatusImplCopyWith(_$BggImportStatusImpl value,
          $Res Function(_$BggImportStatusImpl) then) =
      __$$BggImportStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String status,
      int total,
      int processed,
      int imported,
      int skipped,
      int failed,
      String? errorCode,
      List<BggPreviewGame> preview});
}

/// @nodoc
class __$$BggImportStatusImplCopyWithImpl<$Res>
    extends _$BggImportStatusCopyWithImpl<$Res, _$BggImportStatusImpl>
    implements _$$BggImportStatusImplCopyWith<$Res> {
  __$$BggImportStatusImplCopyWithImpl(
      _$BggImportStatusImpl _value, $Res Function(_$BggImportStatusImpl) _then)
      : super(_value, _then);

  /// Create a copy of BggImportStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? total = null,
    Object? processed = null,
    Object? imported = null,
    Object? skipped = null,
    Object? failed = null,
    Object? errorCode = freezed,
    Object? preview = null,
  }) {
    return _then(_$BggImportStatusImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      processed: null == processed
          ? _value.processed
          : processed // ignore: cast_nullable_to_non_nullable
              as int,
      imported: null == imported
          ? _value.imported
          : imported // ignore: cast_nullable_to_non_nullable
              as int,
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as int,
      failed: null == failed
          ? _value.failed
          : failed // ignore: cast_nullable_to_non_nullable
              as int,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      preview: null == preview
          ? _value._preview
          : preview // ignore: cast_nullable_to_non_nullable
              as List<BggPreviewGame>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BggImportStatusImpl extends _BggImportStatus {
  const _$BggImportStatusImpl(
      {this.status = 'idle',
      this.total = 0,
      this.processed = 0,
      this.imported = 0,
      this.skipped = 0,
      this.failed = 0,
      this.errorCode,
      final List<BggPreviewGame> preview = const <BggPreviewGame>[]})
      : _preview = preview,
        super._();

  factory _$BggImportStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$BggImportStatusImplFromJson(json);

  /// `idle` | `running` | `done` | `failed`.
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final int total;
  @override
  @JsonKey()
  final int processed;
  @override
  @JsonKey()
  final int imported;
  @override
  @JsonKey()
  final int skipped;
  @override
  @JsonKey()
  final int failed;
  @override
  final String? errorCode;

  /// First imported games (`{gameId, title, thumbnailUrl}`) for the
  /// success preview row.
  final List<BggPreviewGame> _preview;

  /// First imported games (`{gameId, title, thumbnailUrl}`) for the
  /// success preview row.
  @override
  @JsonKey()
  List<BggPreviewGame> get preview {
    if (_preview is EqualUnmodifiableListView) return _preview;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preview);
  }

  @override
  String toString() {
    return 'BggImportStatus(status: $status, total: $total, processed: $processed, imported: $imported, skipped: $skipped, failed: $failed, errorCode: $errorCode, preview: $preview)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BggImportStatusImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.processed, processed) ||
                other.processed == processed) &&
            (identical(other.imported, imported) ||
                other.imported == imported) &&
            (identical(other.skipped, skipped) || other.skipped == skipped) &&
            (identical(other.failed, failed) || other.failed == failed) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            const DeepCollectionEquality().equals(other._preview, _preview));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      total,
      processed,
      imported,
      skipped,
      failed,
      errorCode,
      const DeepCollectionEquality().hash(_preview));

  /// Create a copy of BggImportStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BggImportStatusImplCopyWith<_$BggImportStatusImpl> get copyWith =>
      __$$BggImportStatusImplCopyWithImpl<_$BggImportStatusImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BggImportStatusImplToJson(
      this,
    );
  }
}

abstract class _BggImportStatus extends BggImportStatus {
  const factory _BggImportStatus(
      {final String status,
      final int total,
      final int processed,
      final int imported,
      final int skipped,
      final int failed,
      final String? errorCode,
      final List<BggPreviewGame> preview}) = _$BggImportStatusImpl;
  const _BggImportStatus._() : super._();

  factory _BggImportStatus.fromJson(Map<String, dynamic> json) =
      _$BggImportStatusImpl.fromJson;

  /// `idle` | `running` | `done` | `failed`.
  @override
  String get status;
  @override
  int get total;
  @override
  int get processed;
  @override
  int get imported;
  @override
  int get skipped;
  @override
  int get failed;
  @override
  String? get errorCode;

  /// First imported games (`{gameId, title, thumbnailUrl}`) for the
  /// success preview row.
  @override
  List<BggPreviewGame> get preview;

  /// Create a copy of BggImportStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BggImportStatusImplCopyWith<_$BggImportStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BggPreviewGame _$BggPreviewGameFromJson(Map<String, dynamic> json) {
  return _BggPreviewGame.fromJson(json);
}

/// @nodoc
mixin _$BggPreviewGame {
  String get gameId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;

  /// Serializes this BggPreviewGame to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BggPreviewGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BggPreviewGameCopyWith<BggPreviewGame> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BggPreviewGameCopyWith<$Res> {
  factory $BggPreviewGameCopyWith(
          BggPreviewGame value, $Res Function(BggPreviewGame) then) =
      _$BggPreviewGameCopyWithImpl<$Res, BggPreviewGame>;
  @useResult
  $Res call({String gameId, String title, String? thumbnailUrl});
}

/// @nodoc
class _$BggPreviewGameCopyWithImpl<$Res, $Val extends BggPreviewGame>
    implements $BggPreviewGameCopyWith<$Res> {
  _$BggPreviewGameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BggPreviewGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? title = null,
    Object? thumbnailUrl = freezed,
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
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BggPreviewGameImplCopyWith<$Res>
    implements $BggPreviewGameCopyWith<$Res> {
  factory _$$BggPreviewGameImplCopyWith(_$BggPreviewGameImpl value,
          $Res Function(_$BggPreviewGameImpl) then) =
      __$$BggPreviewGameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String gameId, String title, String? thumbnailUrl});
}

/// @nodoc
class __$$BggPreviewGameImplCopyWithImpl<$Res>
    extends _$BggPreviewGameCopyWithImpl<$Res, _$BggPreviewGameImpl>
    implements _$$BggPreviewGameImplCopyWith<$Res> {
  __$$BggPreviewGameImplCopyWithImpl(
      _$BggPreviewGameImpl _value, $Res Function(_$BggPreviewGameImpl) _then)
      : super(_value, _then);

  /// Create a copy of BggPreviewGame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? title = null,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_$BggPreviewGameImpl(
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BggPreviewGameImpl implements _BggPreviewGame {
  const _$BggPreviewGameImpl(
      {required this.gameId, this.title = '', this.thumbnailUrl});

  factory _$BggPreviewGameImpl.fromJson(Map<String, dynamic> json) =>
      _$$BggPreviewGameImplFromJson(json);

  @override
  final String gameId;
  @override
  @JsonKey()
  final String title;
  @override
  final String? thumbnailUrl;

  @override
  String toString() {
    return 'BggPreviewGame(gameId: $gameId, title: $title, thumbnailUrl: $thumbnailUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BggPreviewGameImpl &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, gameId, title, thumbnailUrl);

  /// Create a copy of BggPreviewGame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BggPreviewGameImplCopyWith<_$BggPreviewGameImpl> get copyWith =>
      __$$BggPreviewGameImplCopyWithImpl<_$BggPreviewGameImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BggPreviewGameImplToJson(
      this,
    );
  }
}

abstract class _BggPreviewGame implements BggPreviewGame {
  const factory _BggPreviewGame(
      {required final String gameId,
      final String title,
      final String? thumbnailUrl}) = _$BggPreviewGameImpl;

  factory _BggPreviewGame.fromJson(Map<String, dynamic> json) =
      _$BggPreviewGameImpl.fromJson;

  @override
  String get gameId;
  @override
  String get title;
  @override
  String? get thumbnailUrl;

  /// Create a copy of BggPreviewGame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BggPreviewGameImplCopyWith<_$BggPreviewGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
