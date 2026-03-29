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
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  int? get minPlayers => throw _privateConstructorUsedError;
  int? get maxPlayers => throw _privateConstructorUsedError;
  int? get minPlayTimeMinutes => throw _privateConstructorUsedError;
  int? get maxPlayTimeMinutes => throw _privateConstructorUsedError;
  double? get averageRating => throw _privateConstructorUsedError;
  int? get bggId => throw _privateConstructorUsedError;
  String? get bggUrl => throw _privateConstructorUsedError;
  List<String> get categories => throw _privateConstructorUsedError;
  List<String> get mechanics => throw _privateConstructorUsedError;
  List<String> get designers => throw _privateConstructorUsedError;

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
      String name,
      String? description,
      String? imageUrl,
      String? thumbnailUrl,
      int? minPlayers,
      int? maxPlayers,
      int? minPlayTimeMinutes,
      int? maxPlayTimeMinutes,
      double? averageRating,
      int? bggId,
      String? bggUrl,
      List<String> categories,
      List<String> mechanics,
      List<String> designers});
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
    Object? minPlayers = freezed,
    Object? maxPlayers = freezed,
    Object? minPlayTimeMinutes = freezed,
    Object? maxPlayTimeMinutes = freezed,
    Object? averageRating = freezed,
    Object? bggId = freezed,
    Object? bggUrl = freezed,
    Object? categories = null,
    Object? mechanics = null,
    Object? designers = null,
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
      minPlayers: freezed == minPlayers
          ? _value.minPlayers
          : minPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayers: freezed == maxPlayers
          ? _value.maxPlayers
          : maxPlayers // ignore: cast_nullable_to_non_nullable
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
      String name,
      String? description,
      String? imageUrl,
      String? thumbnailUrl,
      int? minPlayers,
      int? maxPlayers,
      int? minPlayTimeMinutes,
      int? maxPlayTimeMinutes,
      double? averageRating,
      int? bggId,
      String? bggUrl,
      List<String> categories,
      List<String> mechanics,
      List<String> designers});
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
    Object? minPlayers = freezed,
    Object? maxPlayers = freezed,
    Object? minPlayTimeMinutes = freezed,
    Object? maxPlayTimeMinutes = freezed,
    Object? averageRating = freezed,
    Object? bggId = freezed,
    Object? bggUrl = freezed,
    Object? categories = null,
    Object? mechanics = null,
    Object? designers = null,
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
      minPlayers: freezed == minPlayers
          ? _value.minPlayers
          : minPlayers // ignore: cast_nullable_to_non_nullable
              as int?,
      maxPlayers: freezed == maxPlayers
          ? _value.maxPlayers
          : maxPlayers // ignore: cast_nullable_to_non_nullable
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameImpl implements _Game {
  const _$GameImpl(
      {required this.id,
      required this.name,
      this.description,
      this.imageUrl,
      this.thumbnailUrl,
      this.minPlayers,
      this.maxPlayers,
      this.minPlayTimeMinutes,
      this.maxPlayTimeMinutes,
      this.averageRating,
      this.bggId,
      this.bggUrl,
      final List<String> categories = const [],
      final List<String> mechanics = const [],
      final List<String> designers = const []})
      : _categories = categories,
        _mechanics = mechanics,
        _designers = designers;

  factory _$GameImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? imageUrl;
  @override
  final String? thumbnailUrl;
  @override
  final int? minPlayers;
  @override
  final int? maxPlayers;
  @override
  final int? minPlayTimeMinutes;
  @override
  final int? maxPlayTimeMinutes;
  @override
  final double? averageRating;
  @override
  final int? bggId;
  @override
  final String? bggUrl;
  final List<String> _categories;
  @override
  @JsonKey()
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  final List<String> _mechanics;
  @override
  @JsonKey()
  List<String> get mechanics {
    if (_mechanics is EqualUnmodifiableListView) return _mechanics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mechanics);
  }

  final List<String> _designers;
  @override
  @JsonKey()
  List<String> get designers {
    if (_designers is EqualUnmodifiableListView) return _designers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_designers);
  }

  @override
  String toString() {
    return 'Game(id: $id, name: $name, description: $description, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, minPlayers: $minPlayers, maxPlayers: $maxPlayers, minPlayTimeMinutes: $minPlayTimeMinutes, maxPlayTimeMinutes: $maxPlayTimeMinutes, averageRating: $averageRating, bggId: $bggId, bggUrl: $bggUrl, categories: $categories, mechanics: $mechanics, designers: $designers)';
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
            (identical(other.minPlayers, minPlayers) ||
                other.minPlayers == minPlayers) &&
            (identical(other.maxPlayers, maxPlayers) ||
                other.maxPlayers == maxPlayers) &&
            (identical(other.minPlayTimeMinutes, minPlayTimeMinutes) ||
                other.minPlayTimeMinutes == minPlayTimeMinutes) &&
            (identical(other.maxPlayTimeMinutes, maxPlayTimeMinutes) ||
                other.maxPlayTimeMinutes == maxPlayTimeMinutes) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.bggId, bggId) || other.bggId == bggId) &&
            (identical(other.bggUrl, bggUrl) || other.bggUrl == bggUrl) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            const DeepCollectionEquality()
                .equals(other._mechanics, _mechanics) &&
            const DeepCollectionEquality()
                .equals(other._designers, _designers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      imageUrl,
      thumbnailUrl,
      minPlayers,
      maxPlayers,
      minPlayTimeMinutes,
      maxPlayTimeMinutes,
      averageRating,
      bggId,
      bggUrl,
      const DeepCollectionEquality().hash(_categories),
      const DeepCollectionEquality().hash(_mechanics),
      const DeepCollectionEquality().hash(_designers));

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

abstract class _Game implements Game {
  const factory _Game(
      {required final String id,
      required final String name,
      final String? description,
      final String? imageUrl,
      final String? thumbnailUrl,
      final int? minPlayers,
      final int? maxPlayers,
      final int? minPlayTimeMinutes,
      final int? maxPlayTimeMinutes,
      final double? averageRating,
      final int? bggId,
      final String? bggUrl,
      final List<String> categories,
      final List<String> mechanics,
      final List<String> designers}) = _$GameImpl;

  factory _Game.fromJson(Map<String, dynamic> json) = _$GameImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String? get imageUrl;
  @override
  String? get thumbnailUrl;
  @override
  int? get minPlayers;
  @override
  int? get maxPlayers;
  @override
  int? get minPlayTimeMinutes;
  @override
  int? get maxPlayTimeMinutes;
  @override
  double? get averageRating;
  @override
  int? get bggId;
  @override
  String? get bggUrl;
  @override
  List<String> get categories;
  @override
  List<String> get mechanics;
  @override
  List<String> get designers;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
