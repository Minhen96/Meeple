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
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  Game get game => throw _privateConstructorUsedError;
  bool get isOwned => throw _privateConstructorUsedError;
  bool get isWishlisted => throw _privateConstructorUsedError;
  bool get isFavorited => throw _privateConstructorUsedError;
  int get playCount => throw _privateConstructorUsedError;
  int? get personalRating => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get lastPlayedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

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
      {String id,
      String userId,
      String gameId,
      Game game,
      bool isOwned,
      bool isWishlisted,
      bool isFavorited,
      int playCount,
      int? personalRating,
      String? notes,
      DateTime? lastPlayedAt,
      DateTime createdAt,
      DateTime? updatedAt});

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
    Object? id = null,
    Object? userId = null,
    Object? gameId = null,
    Object? game = null,
    Object? isOwned = null,
    Object? isWishlisted = null,
    Object? isFavorited = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
    Object? lastPlayedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
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
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      lastPlayedAt: freezed == lastPlayedAt
          ? _value.lastPlayedAt
          : lastPlayedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
      {String id,
      String userId,
      String gameId,
      Game game,
      bool isOwned,
      bool isWishlisted,
      bool isFavorited,
      int playCount,
      int? personalRating,
      String? notes,
      DateTime? lastPlayedAt,
      DateTime createdAt,
      DateTime? updatedAt});

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
    Object? id = null,
    Object? userId = null,
    Object? gameId = null,
    Object? game = null,
    Object? isOwned = null,
    Object? isWishlisted = null,
    Object? isFavorited = null,
    Object? playCount = null,
    Object? personalRating = freezed,
    Object? notes = freezed,
    Object? lastPlayedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$UserGameImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
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
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      lastPlayedAt: freezed == lastPlayedAt
          ? _value.lastPlayedAt
          : lastPlayedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
class _$UserGameImpl implements _UserGame {
  const _$UserGameImpl(
      {required this.id,
      required this.userId,
      required this.gameId,
      required this.game,
      this.isOwned = false,
      this.isWishlisted = false,
      this.isFavorited = false,
      this.playCount = 0,
      this.personalRating,
      this.notes,
      this.lastPlayedAt,
      required this.createdAt,
      this.updatedAt});

  factory _$UserGameImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserGameImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
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
  final int? personalRating;
  @override
  final String? notes;
  @override
  final DateTime? lastPlayedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'UserGame(id: $id, userId: $userId, gameId: $gameId, game: $game, isOwned: $isOwned, isWishlisted: $isWishlisted, isFavorited: $isFavorited, playCount: $playCount, personalRating: $personalRating, notes: $notes, lastPlayedAt: $lastPlayedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserGameImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
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
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.lastPlayedAt, lastPlayedAt) ||
                other.lastPlayedAt == lastPlayedAt) &&
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
      userId,
      gameId,
      game,
      isOwned,
      isWishlisted,
      isFavorited,
      playCount,
      personalRating,
      notes,
      lastPlayedAt,
      createdAt,
      updatedAt);

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

abstract class _UserGame implements UserGame {
  const factory _UserGame(
      {required final String id,
      required final String userId,
      required final String gameId,
      required final Game game,
      final bool isOwned,
      final bool isWishlisted,
      final bool isFavorited,
      final int playCount,
      final int? personalRating,
      final String? notes,
      final DateTime? lastPlayedAt,
      required final DateTime createdAt,
      final DateTime? updatedAt}) = _$UserGameImpl;

  factory _UserGame.fromJson(Map<String, dynamic> json) =
      _$UserGameImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
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
  int? get personalRating;
  @override
  String? get notes;
  @override
  DateTime? get lastPlayedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of UserGame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserGameImplCopyWith<_$UserGameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
