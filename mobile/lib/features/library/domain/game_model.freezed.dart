// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Game _$GameFromJson(Map<String, dynamic> json) {
  return _Game.fromJson(json);
}

/// @nodoc
mixin _$Game {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'title', defaultValue: '')
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  int? get yearPublished => throw _privateConstructorUsedError;
  int? get minPlayers => throw _privateConstructorUsedError;
  int? get maxPlayers => throw _privateConstructorUsedError;
  int? get minAge => throw _privateConstructorUsedError;
  @JsonKey(name: 'playTime')
  int? get minPlayTimeMinutes => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readPlayTime)
  int? get maxPlayTimeMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'bggRating')
  double? get averageRating => throw _privateConstructorUsedError;
  @JsonKey(name: 'complexityWeight')
  double? get complexity => throw _privateConstructorUsedError;
  int? get rank => throw _privateConstructorUsedError;
  int? get bggId => throw _privateConstructorUsedError;
  String? get bggUrl => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: <String>[])
  List<String> get categories => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: <String>[])
  List<String> get mechanics => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: <String>[])
  List<String> get designers => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: <String>[])
  List<String> get publishers => throw _privateConstructorUsedError;
  bool get hasRulebook => throw _privateConstructorUsedError;

  /// GAP §6.1 [WP4] additions to `GameDetailResponse`.
  double? get friendAvgRating => throw _privateConstructorUsedError;
  int get friendRatingCount => throw _privateConstructorUsedError;
  List<UserSummary> get ownedByFriends => throw _privateConstructorUsedError;

  /// Serializes this Game to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameCopyWith<Game> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameCopyWith<$Res> {
  factory $GameCopyWith(Game value, $Res Function(Game) then) =
      _$GameCopyWithImpl<$Res, Game>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'title', defaultValue: '') String name,
      String? description,
      String? imageUrl,
      String? thumbnailUrl,
      int? yearPublished,
      int? minPlayers,
      int? maxPlayers,
      int? minAge,
      @JsonKey(name: 'playTime') int? minPlayTimeMinutes,
      @JsonKey(readValue: _readPlayTime) int? maxPlayTimeMinutes,
      @JsonKey(name: 'bggRating') double? averageRating,
      @JsonKey(name: 'complexityWeight') double? complexity,
      int? rank,
      int? bggId,
      String? bggUrl,
      @JsonKey(defaultValue: <String>[]) List<String> categories,
      @JsonKey(defaultValue: <String>[]) List<String> mechanics,
      @JsonKey(defaultValue: <String>[]) List<String> designers,
      @JsonKey(defaultValue: <String>[]) List<String> publishers,
      bool hasRulebook,
      double? friendAvgRating,
      int friendRatingCount,
      List<UserSummary> ownedByFriends});
}

/// @nodoc
class _$GameCopyWithImpl<$Res, $Val extends Game>
    implements $GameCopyWith<$Res> {
  _$GameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? imageUrl = freezed,
    Object? thumbnailUrl = freezed,
    Object? yearPublished = freezed,
    Object? minPlayers = freezed,
    Object? maxPlayers = freezed,
    Object? minAge = freezed,
    Object? minPlayTimeMinutes = freezed,
    Object? maxPlayTimeMinutes = freezed,
    Object? averageRating = freezed,
    Object? complexity = freezed,
    Object? rank = freezed,
    Object? bggId = freezed,
    Object? bggUrl = freezed,
    Object? categories = null,
    Object? mechanics = null,
    Object? designers = null,
    Object? publishers = null,
    Object? hasRulebook = null,
    Object? friendAvgRating = freezed,
    Object? friendRatingCount = null,
    Object? ownedByFriends = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      yearPublished: freezed == yearPublished
          ? _value.yearPublished
          : yearPublished // ignore: cast_nullable_to_non_nullable
              as int?,
      minPlayers: freezed == minPlayers
          ? _value.minPlayers
          : minPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayers: freezed == maxPlayers
          ? _value.maxPlayers
          : maxPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      minAge: freezed == minAge
          ? _value.minAge
          : minAge // ignore: cast_nullable_to_non_nullable
              as int?,
      minPlayTimeMinutes: freezed == minPlayTimeMinutes
          ? _value.minPlayTimeMinutes
          : minPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayTimeMinutes: freezed == maxPlayTimeMinutes
          ? _value.maxPlayTimeMinutes
          : maxPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      averageRating: freezed == averageRating
          ? _value.averageRating
          : averageRating // ignore: cast_nullable_to_non_nullable
              as double?,
      complexity: freezed == complexity
          ? _value.complexity
          : complexity // ignore: cast_nullable_to_non_nullable
              as double?,
      rank: freezed == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int?,
      bggId: freezed == bggId
          ? _value.bggId
          : bggId // ignore: cast_nullable_to_non_nullable
              as int?,
      bggUrl: freezed == bggUrl
          ? _value.bggUrl
          : bggUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      categories: null == categories
          ? _value.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      mechanics: null == mechanics
          ? _value.mechanics
          : mechanics // ignore: cast_nullable_to_non_nullable
              as List<String>,
      designers: null == designers
          ? _value.designers
          : designers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      publishers: null == publishers
          ? _value.publishers
          : publishers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      hasRulebook: null == hasRulebook
          ? _value.hasRulebook
          : hasRulebook // ignore: cast_nullable_to_non_nullable
              as bool,
      friendAvgRating: freezed == friendAvgRating
          ? _value.friendAvgRating
          : friendAvgRating // ignore: cast_nullable_to_non_nullable
              as double?,
      friendRatingCount: null == friendRatingCount
          ? _value.friendRatingCount
          : friendRatingCount // ignore: cast_nullable_to_non_nullable
              as int,
      ownedByFriends: null == ownedByFriends
          ? _value.ownedByFriends
          : ownedByFriends // ignore: cast_nullable_to_non_nullable
              as List<UserSummary>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameImplCopyWith<$Res> implements $GameCopyWith<$Res> {
  factory _$$GameImplCopyWith(
          _$GameImpl value, $Res Function(_$GameImpl) then) =
      __$$GameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'title', defaultValue: '') String name,
      String? description,
      String? imageUrl,
      String? thumbnailUrl,
      int? yearPublished,
      int? minPlayers,
      int? maxPlayers,
      int? minAge,
      @JsonKey(name: 'playTime') int? minPlayTimeMinutes,
      @JsonKey(readValue: _readPlayTime) int? maxPlayTimeMinutes,
      @JsonKey(name: 'bggRating') double? averageRating,
      @JsonKey(name: 'complexityWeight') double? complexity,
      int? rank,
      int? bggId,
      String? bggUrl,
      @JsonKey(defaultValue: <String>[]) List<String> categories,
      @JsonKey(defaultValue: <String>[]) List<String> mechanics,
      @JsonKey(defaultValue: <String>[]) List<String> designers,
      @JsonKey(defaultValue: <String>[]) List<String> publishers,
      bool hasRulebook,
      double? friendAvgRating,
      int friendRatingCount,
      List<UserSummary> ownedByFriends});
}

/// @nodoc
class __$$GameImplCopyWithImpl<$Res>
    extends _$GameCopyWithImpl<$Res, _$GameImpl>
    implements _$$GameImplCopyWith<$Res> {
  __$$GameImplCopyWithImpl(_$GameImpl _value, $Res Function(_$GameImpl) _then)
      : super(_value, _then);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? imageUrl = freezed,
    Object? thumbnailUrl = freezed,
    Object? yearPublished = freezed,
    Object? minPlayers = freezed,
    Object? maxPlayers = freezed,
    Object? minAge = freezed,
    Object? minPlayTimeMinutes = freezed,
    Object? maxPlayTimeMinutes = freezed,
    Object? averageRating = freezed,
    Object? complexity = freezed,
    Object? rank = freezed,
    Object? bggId = freezed,
    Object? bggUrl = freezed,
    Object? categories = null,
    Object? mechanics = null,
    Object? designers = null,
    Object? publishers = null,
    Object? hasRulebook = null,
    Object? friendAvgRating = freezed,
    Object? friendRatingCount = null,
    Object? ownedByFriends = null,
  }) {
    return _then(_$GameImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      yearPublished: freezed == yearPublished
          ? _value.yearPublished
          : yearPublished // ignore: cast_nullable_to_non_nullable
              as int?,
      minPlayers: freezed == minPlayers
          ? _value.minPlayers
          : minPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayers: freezed == maxPlayers
          ? _value.maxPlayers
          : maxPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      minAge: freezed == minAge
          ? _value.minAge
          : minAge // ignore: cast_nullable_to_non_nullable
              as int?,
      minPlayTimeMinutes: freezed == minPlayTimeMinutes
          ? _value.minPlayTimeMinutes
          : minPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayTimeMinutes: freezed == maxPlayTimeMinutes
          ? _value.maxPlayTimeMinutes
          : maxPlayTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      averageRating: freezed == averageRating
          ? _value.averageRating
          : averageRating // ignore: cast_nullable_to_non_nullable
              as double?,
      complexity: freezed == complexity
          ? _value.complexity
          : complexity // ignore: cast_nullable_to_non_nullable
              as double?,
      rank: freezed == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int?,
      bggId: freezed == bggId
          ? _value.bggId
          : bggId // ignore: cast_nullable_to_non_nullable
              as int?,
      bggUrl: freezed == bggUrl
          ? _value.bggUrl
          : bggUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      categories: null == categories
          ? _value._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      mechanics: null == mechanics
          ? _value._mechanics
          : mechanics // ignore: cast_nullable_to_non_nullable
              as List<String>,
      designers: null == designers
          ? _value._designers
          : designers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      publishers: null == publishers
          ? _value._publishers
          : publishers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      hasRulebook: null == hasRulebook
          ? _value.hasRulebook
          : hasRulebook // ignore: cast_nullable_to_non_nullable
              as bool,
      friendAvgRating: freezed == friendAvgRating
          ? _value.friendAvgRating
          : friendAvgRating // ignore: cast_nullable_to_non_nullable
              as double?,
      friendRatingCount: null == friendRatingCount
          ? _value.friendRatingCount
          : friendRatingCount // ignore: cast_nullable_to_non_nullable
              as int,
      ownedByFriends: null == ownedByFriends
          ? _value._ownedByFriends
          : ownedByFriends // ignore: cast_nullable_to_non_nullable
              as List<UserSummary>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameImpl extends _Game {
  const _$GameImpl(
      {required this.id,
      @JsonKey(name: 'title', defaultValue: '') required this.name,
      this.description,
      this.imageUrl,
      this.thumbnailUrl,
      this.yearPublished,
      this.minPlayers,
      this.maxPlayers,
      this.minAge,
      @JsonKey(name: 'playTime') this.minPlayTimeMinutes,
      @JsonKey(readValue: _readPlayTime) this.maxPlayTimeMinutes,
      @JsonKey(name: 'bggRating') this.averageRating,
      @JsonKey(name: 'complexityWeight') this.complexity,
      this.rank,
      this.bggId,
      this.bggUrl,
      @JsonKey(defaultValue: <String>[]) required final List<String> categories,
      @JsonKey(defaultValue: <String>[]) required final List<String> mechanics,
      @JsonKey(defaultValue: <String>[]) required final List<String> designers,
      @JsonKey(defaultValue: <String>[]) required final List<String> publishers,
      this.hasRulebook = false,
      this.friendAvgRating,
      this.friendRatingCount = 0,
      final List<UserSummary> ownedByFriends = const <UserSummary>[]})
      : _categories = categories,
        _mechanics = mechanics,
        _designers = designers,
        _publishers = publishers,
        _ownedByFriends = ownedByFriends,
        super._();

  factory _$GameImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'title', defaultValue: '')
  final String name;
  @override
  final String? description;
  @override
  final String? imageUrl;
  @override
  final String? thumbnailUrl;
  @override
  final int? yearPublished;
  @override
  final int? minPlayers;
  @override
  final int? maxPlayers;
  @override
  final int? minAge;
  @override
  @JsonKey(name: 'playTime')
  final int? minPlayTimeMinutes;
  @override
  @JsonKey(readValue: _readPlayTime)
  final int? maxPlayTimeMinutes;
  @override
  @JsonKey(name: 'bggRating')
  final double? averageRating;
  @override
  @JsonKey(name: 'complexityWeight')
  final double? complexity;
  @override
  final int? rank;
  @override
  final int? bggId;
  @override
  final String? bggUrl;
  final List<String> _categories;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  final List<String> _mechanics;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get mechanics {
    if (_mechanics is EqualUnmodifiableListView) return _mechanics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mechanics);
  }

  final List<String> _designers;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get designers {
    if (_designers is EqualUnmodifiableListView) return _designers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_designers);
  }

  final List<String> _publishers;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get publishers {
    if (_publishers is EqualUnmodifiableListView) return _publishers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_publishers);
  }

  @override
  @JsonKey()
  final bool hasRulebook;

  /// GAP §6.1 [WP4] additions to `GameDetailResponse`.
  @override
  final double? friendAvgRating;
  @override
  @JsonKey()
  final int friendRatingCount;
  final List<UserSummary> _ownedByFriends;
  @override
  @JsonKey()
  List<UserSummary> get ownedByFriends {
    if (_ownedByFriends is EqualUnmodifiableListView) return _ownedByFriends;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ownedByFriends);
  }

  @override
  String toString() {
    return 'Game(id: $id, name: $name, description: $description, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, yearPublished: $yearPublished, minPlayers: $minPlayers, maxPlayers: $maxPlayers, minAge: $minAge, minPlayTimeMinutes: $minPlayTimeMinutes, maxPlayTimeMinutes: $maxPlayTimeMinutes, averageRating: $averageRating, complexity: $complexity, rank: $rank, bggId: $bggId, bggUrl: $bggUrl, categories: $categories, mechanics: $mechanics, designers: $designers, publishers: $publishers, hasRulebook: $hasRulebook, friendAvgRating: $friendAvgRating, friendRatingCount: $friendRatingCount, ownedByFriends: $ownedByFriends)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.yearPublished, yearPublished) ||
                other.yearPublished == yearPublished) &&
            (identical(other.minPlayers, minPlayers) ||
                other.minPlayers == minPlayers) &&
            (identical(other.maxPlayers, maxPlayers) ||
                other.maxPlayers == maxPlayers) &&
            (identical(other.minAge, minAge) || other.minAge == minAge) &&
            (identical(other.minPlayTimeMinutes, minPlayTimeMinutes) ||
                other.minPlayTimeMinutes == minPlayTimeMinutes) &&
            (identical(other.maxPlayTimeMinutes, maxPlayTimeMinutes) ||
                other.maxPlayTimeMinutes == maxPlayTimeMinutes) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.complexity, complexity) ||
                other.complexity == complexity) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.bggId, bggId) || other.bggId == bggId) &&
            (identical(other.bggUrl, bggUrl) || other.bggUrl == bggUrl) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            const DeepCollectionEquality()
                .equals(other._mechanics, _mechanics) &&
            const DeepCollectionEquality()
                .equals(other._designers, _designers) &&
            const DeepCollectionEquality()
                .equals(other._publishers, _publishers) &&
            (identical(other.hasRulebook, hasRulebook) ||
                other.hasRulebook == hasRulebook) &&
            (identical(other.friendAvgRating, friendAvgRating) ||
                other.friendAvgRating == friendAvgRating) &&
            (identical(other.friendRatingCount, friendRatingCount) ||
                other.friendRatingCount == friendRatingCount) &&
            const DeepCollectionEquality()
                .equals(other._ownedByFriends, _ownedByFriends));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        description,
        imageUrl,
        thumbnailUrl,
        yearPublished,
        minPlayers,
        maxPlayers,
        minAge,
        minPlayTimeMinutes,
        maxPlayTimeMinutes,
        averageRating,
        complexity,
        rank,
        bggId,
        bggUrl,
        const DeepCollectionEquality().hash(_categories),
        const DeepCollectionEquality().hash(_mechanics),
        const DeepCollectionEquality().hash(_designers),
        const DeepCollectionEquality().hash(_publishers),
        hasRulebook,
        friendAvgRating,
        friendRatingCount,
        const DeepCollectionEquality().hash(_ownedByFriends)
      ]);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      __$$GameImplCopyWithImpl<_$GameImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameImplToJson(
      this,
    );
  }
}

abstract class _Game extends Game {
  const factory _Game(
      {required final String id,
      @JsonKey(name: 'title', defaultValue: '') required final String name,
      final String? description,
      final String? imageUrl,
      final String? thumbnailUrl,
      final int? yearPublished,
      final int? minPlayers,
      final int? maxPlayers,
      final int? minAge,
      @JsonKey(name: 'playTime') final int? minPlayTimeMinutes,
      @JsonKey(readValue: _readPlayTime) final int? maxPlayTimeMinutes,
      @JsonKey(name: 'bggRating') final double? averageRating,
      @JsonKey(name: 'complexityWeight') final double? complexity,
      final int? rank,
      final int? bggId,
      final String? bggUrl,
      @JsonKey(defaultValue: <String>[]) required final List<String> categories,
      @JsonKey(defaultValue: <String>[]) required final List<String> mechanics,
      @JsonKey(defaultValue: <String>[]) required final List<String> designers,
      @JsonKey(defaultValue: <String>[]) required final List<String> publishers,
      final bool hasRulebook,
      final double? friendAvgRating,
      final int friendRatingCount,
      final List<UserSummary> ownedByFriends}) = _$GameImpl;
  const _Game._() : super._();

  factory _Game.fromJson(Map<String, dynamic> json) = _$GameImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'title', defaultValue: '')
  String get name;
  @override
  String? get description;
  @override
  String? get imageUrl;
  @override
  String? get thumbnailUrl;
  @override
  int? get yearPublished;
  @override
  int? get minPlayers;
  @override
  int? get maxPlayers;
  @override
  int? get minAge;
  @override
  @JsonKey(name: 'playTime')
  int? get minPlayTimeMinutes;
  @override
  @JsonKey(readValue: _readPlayTime)
  int? get maxPlayTimeMinutes;
  @override
  @JsonKey(name: 'bggRating')
  double? get averageRating;
  @override
  @JsonKey(name: 'complexityWeight')
  double? get complexity;
  @override
  int? get rank;
  @override
  int? get bggId;
  @override
  String? get bggUrl;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get categories;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get mechanics;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get designers;
  @override
  @JsonKey(defaultValue: <String>[])
  List<String> get publishers;
  @override
  bool get hasRulebook;

  /// GAP §6.1 [WP4] additions to `GameDetailResponse`.
  @override
  double? get friendAvgRating;
  @override
  int get friendRatingCount;
  @override
  List<UserSummary> get ownedByFriends;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
