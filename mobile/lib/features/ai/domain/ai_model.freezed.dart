// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ConversationTurn _$ConversationTurnFromJson(Map<String, dynamic> json) {
  return _ConversationTurn.fromJson(json);
}

/// @nodoc
mixin _$ConversationTurn {
  String get question => throw _privateConstructorUsedError;
  String get answer => throw _privateConstructorUsedError;

  /// Serializes this ConversationTurn to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationTurn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationTurnCopyWith<ConversationTurn> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationTurnCopyWith<$Res> {
  factory $ConversationTurnCopyWith(
          ConversationTurn value, $Res Function(ConversationTurn) then) =
      _$ConversationTurnCopyWithImpl<$Res, ConversationTurn>;
  @useResult
  $Res call({String question, String answer});
}

/// @nodoc
class _$ConversationTurnCopyWithImpl<$Res, $Val extends ConversationTurn>
    implements $ConversationTurnCopyWith<$Res> {
  _$ConversationTurnCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationTurn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? answer = null,
  }) {
    return _then(_value.copyWith(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConversationTurnImplCopyWith<$Res>
    implements $ConversationTurnCopyWith<$Res> {
  factory _$$ConversationTurnImplCopyWith(_$ConversationTurnImpl value,
          $Res Function(_$ConversationTurnImpl) then) =
      __$$ConversationTurnImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String question, String answer});
}

/// @nodoc
class __$$ConversationTurnImplCopyWithImpl<$Res>
    extends _$ConversationTurnCopyWithImpl<$Res, _$ConversationTurnImpl>
    implements _$$ConversationTurnImplCopyWith<$Res> {
  __$$ConversationTurnImplCopyWithImpl(_$ConversationTurnImpl _value,
      $Res Function(_$ConversationTurnImpl) _then)
      : super(_value, _then);

  /// Create a copy of ConversationTurn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? answer = null,
  }) {
    return _then(_$ConversationTurnImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversationTurnImpl implements _ConversationTurn {
  const _$ConversationTurnImpl({required this.question, required this.answer});

  factory _$ConversationTurnImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationTurnImplFromJson(json);

  @override
  final String question;
  @override
  final String answer;

  @override
  String toString() {
    return 'ConversationTurn(question: $question, answer: $answer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationTurnImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.answer, answer) || other.answer == answer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, question, answer);

  /// Create a copy of ConversationTurn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationTurnImplCopyWith<_$ConversationTurnImpl> get copyWith =>
      __$$ConversationTurnImplCopyWithImpl<_$ConversationTurnImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationTurnImplToJson(
      this,
    );
  }
}

abstract class _ConversationTurn implements ConversationTurn {
  const factory _ConversationTurn(
      {required final String question,
      required final String answer}) = _$ConversationTurnImpl;

  factory _ConversationTurn.fromJson(Map<String, dynamic> json) =
      _$ConversationTurnImpl.fromJson;

  @override
  String get question;
  @override
  String get answer;

  /// Create a copy of ConversationTurn
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationTurnImplCopyWith<_$ConversationTurnImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AiAnswer _$AiAnswerFromJson(Map<String, dynamic> json) {
  return _AiAnswer.fromJson(json);
}

/// @nodoc
mixin _$AiAnswer {
  String get answer => throw _privateConstructorUsedError;

  /// `rulebook` | `general`.
  String? get sourceMode => throw _privateConstructorUsedError;
  String? get disclaimer => throw _privateConstructorUsedError;
  bool get cached => throw _privateConstructorUsedError;

  /// Serializes this AiAnswer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiAnswerCopyWith<AiAnswer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiAnswerCopyWith<$Res> {
  factory $AiAnswerCopyWith(AiAnswer value, $Res Function(AiAnswer) then) =
      _$AiAnswerCopyWithImpl<$Res, AiAnswer>;
  @useResult
  $Res call(
      {String answer, String? sourceMode, String? disclaimer, bool cached});
}

/// @nodoc
class _$AiAnswerCopyWithImpl<$Res, $Val extends AiAnswer>
    implements $AiAnswerCopyWith<$Res> {
  _$AiAnswerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? sourceMode = freezed,
    Object? disclaimer = freezed,
    Object? cached = null,
  }) {
    return _then(_value.copyWith(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      sourceMode: freezed == sourceMode
          ? _value.sourceMode
          : sourceMode // ignore: cast_nullable_to_non_nullable
              as String?,
      disclaimer: freezed == disclaimer
          ? _value.disclaimer
          : disclaimer // ignore: cast_nullable_to_non_nullable
              as String?,
      cached: null == cached
          ? _value.cached
          : cached // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiAnswerImplCopyWith<$Res>
    implements $AiAnswerCopyWith<$Res> {
  factory _$$AiAnswerImplCopyWith(
          _$AiAnswerImpl value, $Res Function(_$AiAnswerImpl) then) =
      __$$AiAnswerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String answer, String? sourceMode, String? disclaimer, bool cached});
}

/// @nodoc
class __$$AiAnswerImplCopyWithImpl<$Res>
    extends _$AiAnswerCopyWithImpl<$Res, _$AiAnswerImpl>
    implements _$$AiAnswerImplCopyWith<$Res> {
  __$$AiAnswerImplCopyWithImpl(
      _$AiAnswerImpl _value, $Res Function(_$AiAnswerImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? sourceMode = freezed,
    Object? disclaimer = freezed,
    Object? cached = null,
  }) {
    return _then(_$AiAnswerImpl(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      sourceMode: freezed == sourceMode
          ? _value.sourceMode
          : sourceMode // ignore: cast_nullable_to_non_nullable
              as String?,
      disclaimer: freezed == disclaimer
          ? _value.disclaimer
          : disclaimer // ignore: cast_nullable_to_non_nullable
              as String?,
      cached: null == cached
          ? _value.cached
          : cached // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiAnswerImpl implements _AiAnswer {
  const _$AiAnswerImpl(
      {required this.answer,
      this.sourceMode,
      this.disclaimer,
      this.cached = false});

  factory _$AiAnswerImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiAnswerImplFromJson(json);

  @override
  final String answer;

  /// `rulebook` | `general`.
  @override
  final String? sourceMode;
  @override
  final String? disclaimer;
  @override
  @JsonKey()
  final bool cached;

  @override
  String toString() {
    return 'AiAnswer(answer: $answer, sourceMode: $sourceMode, disclaimer: $disclaimer, cached: $cached)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiAnswerImpl &&
            (identical(other.answer, answer) || other.answer == answer) &&
            (identical(other.sourceMode, sourceMode) ||
                other.sourceMode == sourceMode) &&
            (identical(other.disclaimer, disclaimer) ||
                other.disclaimer == disclaimer) &&
            (identical(other.cached, cached) || other.cached == cached));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, answer, sourceMode, disclaimer, cached);

  /// Create a copy of AiAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiAnswerImplCopyWith<_$AiAnswerImpl> get copyWith =>
      __$$AiAnswerImplCopyWithImpl<_$AiAnswerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiAnswerImplToJson(
      this,
    );
  }
}

abstract class _AiAnswer implements AiAnswer {
  const factory _AiAnswer(
      {required final String answer,
      final String? sourceMode,
      final String? disclaimer,
      final bool cached}) = _$AiAnswerImpl;

  factory _AiAnswer.fromJson(Map<String, dynamic> json) =
      _$AiAnswerImpl.fromJson;

  @override
  String get answer;

  /// `rulebook` | `general`.
  @override
  String? get sourceMode;
  @override
  String? get disclaimer;
  @override
  bool get cached;

  /// Create a copy of AiAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiAnswerImplCopyWith<_$AiAnswerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
