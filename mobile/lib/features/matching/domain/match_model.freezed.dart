// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MatchRequest _$MatchRequestFromJson(Map<String, dynamic> json) {
  return _MatchRequest.fromJson(json);
}

/// @nodoc
mixin _$MatchRequest {
  String get id => throw _privateConstructorUsedError;
  Game get game => throw _privateConstructorUsedError;
  DateTime? get availableFrom => throw _privateConstructorUsedError;
  DateTime? get availableTo => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this MatchRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchRequestCopyWith<MatchRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchRequestCopyWith<$Res> {
  factory $MatchRequestCopyWith(
          MatchRequest value, $Res Function(MatchRequest) then) =
      _$MatchRequestCopyWithImpl<$Res, MatchRequest>;
  @useResult
  $Res call(
      {String id,
      Game game,
      DateTime? availableFrom,
      DateTime? availableTo,
      String status,
      DateTime? createdAt});

  $GameCopyWith<$Res> get game;
}

/// @nodoc
class _$MatchRequestCopyWithImpl<$Res, $Val extends MatchRequest>
    implements $MatchRequestCopyWith<$Res> {
  _$MatchRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? game = null,
    Object? availableFrom = freezed,
    Object? availableTo = freezed,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      availableFrom: freezed == availableFrom
          ? _value.availableFrom
          : availableFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      availableTo: freezed == availableTo
          ? _value.availableTo
          : availableTo // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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

  /// Create a copy of MatchRequest
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
abstract class _$$MatchRequestImplCopyWith<$Res>
    implements $MatchRequestCopyWith<$Res> {
  factory _$$MatchRequestImplCopyWith(
          _$MatchRequestImpl value, $Res Function(_$MatchRequestImpl) then) =
      __$$MatchRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      Game game,
      DateTime? availableFrom,
      DateTime? availableTo,
      String status,
      DateTime? createdAt});

  @override
  $GameCopyWith<$Res> get game;
}

/// @nodoc
class __$$MatchRequestImplCopyWithImpl<$Res>
    extends _$MatchRequestCopyWithImpl<$Res, _$MatchRequestImpl>
    implements _$$MatchRequestImplCopyWith<$Res> {
  __$$MatchRequestImplCopyWithImpl(
      _$MatchRequestImpl _value, $Res Function(_$MatchRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatchRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? game = null,
    Object? availableFrom = freezed,
    Object? availableTo = freezed,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$MatchRequestImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      availableFrom: freezed == availableFrom
          ? _value.availableFrom
          : availableFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      availableTo: freezed == availableTo
          ? _value.availableTo
          : availableTo // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
class _$MatchRequestImpl implements _MatchRequest {
  const _$MatchRequestImpl(
      {required this.id,
      required this.game,
      this.availableFrom,
      this.availableTo,
      this.status = 'ACTIVE',
      this.createdAt});

  factory _$MatchRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchRequestImplFromJson(json);

  @override
  final String id;
  @override
  final Game game;
  @override
  final DateTime? availableFrom;
  @override
  final DateTime? availableTo;
  @override
  @JsonKey()
  final String status;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'MatchRequest(id: $id, game: $game, availableFrom: $availableFrom, availableTo: $availableTo, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.game, game) || other.game == game) &&
            (identical(other.availableFrom, availableFrom) ||
                other.availableFrom == availableFrom) &&
            (identical(other.availableTo, availableTo) ||
                other.availableTo == availableTo) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, game, availableFrom, availableTo, status, createdAt);

  /// Create a copy of MatchRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchRequestImplCopyWith<_$MatchRequestImpl> get copyWith =>
      __$$MatchRequestImplCopyWithImpl<_$MatchRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchRequestImplToJson(
      this,
    );
  }
}

abstract class _MatchRequest implements MatchRequest {
  const factory _MatchRequest(
      {required final String id,
      required final Game game,
      final DateTime? availableFrom,
      final DateTime? availableTo,
      final String status,
      final DateTime? createdAt}) = _$MatchRequestImpl;

  factory _MatchRequest.fromJson(Map<String, dynamic> json) =
      _$MatchRequestImpl.fromJson;

  @override
  String get id;
  @override
  Game get game;
  @override
  DateTime? get availableFrom;
  @override
  DateTime? get availableTo;
  @override
  String get status;
  @override
  DateTime? get createdAt;

  /// Create a copy of MatchRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchRequestImplCopyWith<_$MatchRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatchGroup _$MatchGroupFromJson(Map<String, dynamic> json) {
  return _MatchGroup.fromJson(json);
}

/// @nodoc
mixin _$MatchGroup {
  String get id => throw _privateConstructorUsedError;
  Game get game => throw _privateConstructorUsedError;
  DateTime? get overlapStart => throw _privateConstructorUsedError;
  DateTime? get overlapEnd => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  List<UserSummary> get members => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this MatchGroup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchGroupCopyWith<MatchGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchGroupCopyWith<$Res> {
  factory $MatchGroupCopyWith(
          MatchGroup value, $Res Function(MatchGroup) then) =
      _$MatchGroupCopyWithImpl<$Res, MatchGroup>;
  @useResult
  $Res call(
      {String id,
      Game game,
      DateTime? overlapStart,
      DateTime? overlapEnd,
      String status,
      List<UserSummary> members,
      DateTime? createdAt});

  $GameCopyWith<$Res> get game;
}

/// @nodoc
class _$MatchGroupCopyWithImpl<$Res, $Val extends MatchGroup>
    implements $MatchGroupCopyWith<$Res> {
  _$MatchGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? game = null,
    Object? overlapStart = freezed,
    Object? overlapEnd = freezed,
    Object? status = null,
    Object? members = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      overlapStart: freezed == overlapStart
          ? _value.overlapStart
          : overlapStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      overlapEnd: freezed == overlapEnd
          ? _value.overlapEnd
          : overlapEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      members: null == members
          ? _value.members
          : members // ignore: cast_nullable_to_non_nullable
              as List<UserSummary>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of MatchGroup
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
abstract class _$$MatchGroupImplCopyWith<$Res>
    implements $MatchGroupCopyWith<$Res> {
  factory _$$MatchGroupImplCopyWith(
          _$MatchGroupImpl value, $Res Function(_$MatchGroupImpl) then) =
      __$$MatchGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      Game game,
      DateTime? overlapStart,
      DateTime? overlapEnd,
      String status,
      List<UserSummary> members,
      DateTime? createdAt});

  @override
  $GameCopyWith<$Res> get game;
}

/// @nodoc
class __$$MatchGroupImplCopyWithImpl<$Res>
    extends _$MatchGroupCopyWithImpl<$Res, _$MatchGroupImpl>
    implements _$$MatchGroupImplCopyWith<$Res> {
  __$$MatchGroupImplCopyWithImpl(
      _$MatchGroupImpl _value, $Res Function(_$MatchGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatchGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? game = null,
    Object? overlapStart = freezed,
    Object? overlapEnd = freezed,
    Object? status = null,
    Object? members = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$MatchGroupImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      game: null == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game,
      overlapStart: freezed == overlapStart
          ? _value.overlapStart
          : overlapStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      overlapEnd: freezed == overlapEnd
          ? _value.overlapEnd
          : overlapEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      members: null == members
          ? _value._members
          : members // ignore: cast_nullable_to_non_nullable
              as List<UserSummary>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchGroupImpl implements _MatchGroup {
  const _$MatchGroupImpl(
      {required this.id,
      required this.game,
      this.overlapStart,
      this.overlapEnd,
      this.status = 'PENDING',
      final List<UserSummary> members = const <UserSummary>[],
      this.createdAt})
      : _members = members;

  factory _$MatchGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchGroupImplFromJson(json);

  @override
  final String id;
  @override
  final Game game;
  @override
  final DateTime? overlapStart;
  @override
  final DateTime? overlapEnd;
  @override
  @JsonKey()
  final String status;
  final List<UserSummary> _members;
  @override
  @JsonKey()
  List<UserSummary> get members {
    if (_members is EqualUnmodifiableListView) return _members;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_members);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'MatchGroup(id: $id, game: $game, overlapStart: $overlapStart, overlapEnd: $overlapEnd, status: $status, members: $members, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchGroupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.game, game) || other.game == game) &&
            (identical(other.overlapStart, overlapStart) ||
                other.overlapStart == overlapStart) &&
            (identical(other.overlapEnd, overlapEnd) ||
                other.overlapEnd == overlapEnd) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._members, _members) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      game,
      overlapStart,
      overlapEnd,
      status,
      const DeepCollectionEquality().hash(_members),
      createdAt);

  /// Create a copy of MatchGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchGroupImplCopyWith<_$MatchGroupImpl> get copyWith =>
      __$$MatchGroupImplCopyWithImpl<_$MatchGroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchGroupImplToJson(
      this,
    );
  }
}

abstract class _MatchGroup implements MatchGroup {
  const factory _MatchGroup(
      {required final String id,
      required final Game game,
      final DateTime? overlapStart,
      final DateTime? overlapEnd,
      final String status,
      final List<UserSummary> members,
      final DateTime? createdAt}) = _$MatchGroupImpl;

  factory _MatchGroup.fromJson(Map<String, dynamic> json) =
      _$MatchGroupImpl.fromJson;

  @override
  String get id;
  @override
  Game get game;
  @override
  DateTime? get overlapStart;
  @override
  DateTime? get overlapEnd;
  @override
  String get status;
  @override
  List<UserSummary> get members;
  @override
  DateTime? get createdAt;

  /// Create a copy of MatchGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchGroupImplCopyWith<_$MatchGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
