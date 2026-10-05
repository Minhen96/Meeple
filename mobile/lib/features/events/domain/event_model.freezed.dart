// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Event _$EventFromJson(Map<String, dynamic> json) {
  return _Event.fromJson(json);
}

/// @nodoc
mixin _$Event {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readHostId)
  String get organizerId => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readHostUsername)
  String get organizerUsername => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readHostDisplayName)
  String get organizerDisplayName => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readHostAvatarUrl)
  String? get organizerAvatarUrl => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: '')
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'scheduledAt')
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: '')
  String get location => throw _privateConstructorUsedError;
  String? get locationDetails => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readMaxParticipants)
  int? get maxAttendees => throw _privateConstructorUsedError;
  @JsonKey(name: 'participantCount')
  int get attendeeCount => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readIsAttending)
  bool get isAttending => throw _privateConstructorUsedError;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | null.
  String? get myRsvp => throw _privateConstructorUsedError;

  /// `INVITE_ONLY` | `FRIENDS` | `PUBLIC`.
  String? get visibility => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readGameIds)
  List<String> get gameIds => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readGameNames)
  List<String> get gameNames => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Event to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventCopyWith<Event> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventCopyWith<$Res> {
  factory $EventCopyWith(Event value, $Res Function(Event) then) =
      _$EventCopyWithImpl<$Res, Event>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(readValue: _readHostId) String organizerId,
      @JsonKey(readValue: _readHostUsername) String organizerUsername,
      @JsonKey(readValue: _readHostDisplayName) String organizerDisplayName,
      @JsonKey(readValue: _readHostAvatarUrl) String? organizerAvatarUrl,
      String title,
      @JsonKey(defaultValue: '') String description,
      @JsonKey(name: 'scheduledAt') DateTime startTime,
      DateTime? endTime,
      @JsonKey(defaultValue: '') String location,
      String? locationDetails,
      @JsonKey(readValue: _readMaxParticipants) int? maxAttendees,
      @JsonKey(name: 'participantCount') int attendeeCount,
      @JsonKey(readValue: _readIsAttending) bool isAttending,
      String? myRsvp,
      String? visibility,
      String? status,
      @JsonKey(readValue: _readGameIds) List<String> gameIds,
      @JsonKey(readValue: _readGameNames) List<String> gameNames,
      DateTime createdAt});
}

/// @nodoc
class _$EventCopyWithImpl<$Res, $Val extends Event>
    implements $EventCopyWith<$Res> {
  _$EventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizerId = null,
    Object? organizerUsername = null,
    Object? organizerDisplayName = null,
    Object? organizerAvatarUrl = freezed,
    Object? title = null,
    Object? description = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? location = null,
    Object? locationDetails = freezed,
    Object? maxAttendees = freezed,
    Object? attendeeCount = null,
    Object? isAttending = null,
    Object? myRsvp = freezed,
    Object? visibility = freezed,
    Object? status = freezed,
    Object? gameIds = null,
    Object? gameNames = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      organizerId: null == organizerId
          ? _value.organizerId
          : organizerId // ignore: cast_nullable_to_non_nullable
              as String,
      organizerUsername: null == organizerUsername
          ? _value.organizerUsername
          : organizerUsername // ignore: cast_nullable_to_non_nullable
              as String,
      organizerDisplayName: null == organizerDisplayName
          ? _value.organizerDisplayName
          : organizerDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      organizerAvatarUrl: freezed == organizerAvatarUrl
          ? _value.organizerAvatarUrl
          : organizerAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      locationDetails: freezed == locationDetails
          ? _value.locationDetails
          : locationDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      maxAttendees: freezed == maxAttendees
          ? _value.maxAttendees
          : maxAttendees // ignore: cast_nullable_to_non_nullable
              as int?,
      attendeeCount: null == attendeeCount
          ? _value.attendeeCount
          : attendeeCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAttending: null == isAttending
          ? _value.isAttending
          : isAttending // ignore: cast_nullable_to_non_nullable
              as bool,
      myRsvp: freezed == myRsvp
          ? _value.myRsvp
          : myRsvp // ignore: cast_nullable_to_non_nullable
              as String?,
      visibility: freezed == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      gameIds: null == gameIds
          ? _value.gameIds
          : gameIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gameNames: null == gameNames
          ? _value.gameNames
          : gameNames // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EventImplCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$$EventImplCopyWith(
          _$EventImpl value, $Res Function(_$EventImpl) then) =
      __$$EventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(readValue: _readHostId) String organizerId,
      @JsonKey(readValue: _readHostUsername) String organizerUsername,
      @JsonKey(readValue: _readHostDisplayName) String organizerDisplayName,
      @JsonKey(readValue: _readHostAvatarUrl) String? organizerAvatarUrl,
      String title,
      @JsonKey(defaultValue: '') String description,
      @JsonKey(name: 'scheduledAt') DateTime startTime,
      DateTime? endTime,
      @JsonKey(defaultValue: '') String location,
      String? locationDetails,
      @JsonKey(readValue: _readMaxParticipants) int? maxAttendees,
      @JsonKey(name: 'participantCount') int attendeeCount,
      @JsonKey(readValue: _readIsAttending) bool isAttending,
      String? myRsvp,
      String? visibility,
      String? status,
      @JsonKey(readValue: _readGameIds) List<String> gameIds,
      @JsonKey(readValue: _readGameNames) List<String> gameNames,
      DateTime createdAt});
}

/// @nodoc
class __$$EventImplCopyWithImpl<$Res>
    extends _$EventCopyWithImpl<$Res, _$EventImpl>
    implements _$$EventImplCopyWith<$Res> {
  __$$EventImplCopyWithImpl(
      _$EventImpl _value, $Res Function(_$EventImpl) _then)
      : super(_value, _then);

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizerId = null,
    Object? organizerUsername = null,
    Object? organizerDisplayName = null,
    Object? organizerAvatarUrl = freezed,
    Object? title = null,
    Object? description = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? location = null,
    Object? locationDetails = freezed,
    Object? maxAttendees = freezed,
    Object? attendeeCount = null,
    Object? isAttending = null,
    Object? myRsvp = freezed,
    Object? visibility = freezed,
    Object? status = freezed,
    Object? gameIds = null,
    Object? gameNames = null,
    Object? createdAt = null,
  }) {
    return _then(_$EventImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      organizerId: null == organizerId
          ? _value.organizerId
          : organizerId // ignore: cast_nullable_to_non_nullable
              as String,
      organizerUsername: null == organizerUsername
          ? _value.organizerUsername
          : organizerUsername // ignore: cast_nullable_to_non_nullable
              as String,
      organizerDisplayName: null == organizerDisplayName
          ? _value.organizerDisplayName
          : organizerDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      organizerAvatarUrl: freezed == organizerAvatarUrl
          ? _value.organizerAvatarUrl
          : organizerAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      locationDetails: freezed == locationDetails
          ? _value.locationDetails
          : locationDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      maxAttendees: freezed == maxAttendees
          ? _value.maxAttendees
          : maxAttendees // ignore: cast_nullable_to_non_nullable
              as int?,
      attendeeCount: null == attendeeCount
          ? _value.attendeeCount
          : attendeeCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAttending: null == isAttending
          ? _value.isAttending
          : isAttending // ignore: cast_nullable_to_non_nullable
              as bool,
      myRsvp: freezed == myRsvp
          ? _value.myRsvp
          : myRsvp // ignore: cast_nullable_to_non_nullable
              as String?,
      visibility: freezed == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      gameIds: null == gameIds
          ? _value._gameIds
          : gameIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gameNames: null == gameNames
          ? _value._gameNames
          : gameNames // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EventImpl implements _Event {
  const _$EventImpl(
      {required this.id,
      @JsonKey(readValue: _readHostId) required this.organizerId,
      @JsonKey(readValue: _readHostUsername) required this.organizerUsername,
      @JsonKey(readValue: _readHostDisplayName)
      required this.organizerDisplayName,
      @JsonKey(readValue: _readHostAvatarUrl) this.organizerAvatarUrl,
      required this.title,
      @JsonKey(defaultValue: '') required this.description,
      @JsonKey(name: 'scheduledAt') required this.startTime,
      this.endTime,
      @JsonKey(defaultValue: '') required this.location,
      this.locationDetails,
      @JsonKey(readValue: _readMaxParticipants) this.maxAttendees,
      @JsonKey(name: 'participantCount') this.attendeeCount = 0,
      @JsonKey(readValue: _readIsAttending) this.isAttending = false,
      this.myRsvp,
      this.visibility,
      this.status,
      @JsonKey(readValue: _readGameIds) final List<String> gameIds = const [],
      @JsonKey(readValue: _readGameNames)
      final List<String> gameNames = const [],
      required this.createdAt})
      : _gameIds = gameIds,
        _gameNames = gameNames;

  factory _$EventImpl.fromJson(Map<String, dynamic> json) =>
      _$$EventImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(readValue: _readHostId)
  final String organizerId;
  @override
  @JsonKey(readValue: _readHostUsername)
  final String organizerUsername;
  @override
  @JsonKey(readValue: _readHostDisplayName)
  final String organizerDisplayName;
  @override
  @JsonKey(readValue: _readHostAvatarUrl)
  final String? organizerAvatarUrl;
  @override
  final String title;
  @override
  @JsonKey(defaultValue: '')
  final String description;
  @override
  @JsonKey(name: 'scheduledAt')
  final DateTime startTime;
  @override
  final DateTime? endTime;
  @override
  @JsonKey(defaultValue: '')
  final String location;
  @override
  final String? locationDetails;
  @override
  @JsonKey(readValue: _readMaxParticipants)
  final int? maxAttendees;
  @override
  @JsonKey(name: 'participantCount')
  final int attendeeCount;
  @override
  @JsonKey(readValue: _readIsAttending)
  final bool isAttending;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | null.
  @override
  final String? myRsvp;

  /// `INVITE_ONLY` | `FRIENDS` | `PUBLIC`.
  @override
  final String? visibility;
  @override
  final String? status;
  final List<String> _gameIds;
  @override
  @JsonKey(readValue: _readGameIds)
  List<String> get gameIds {
    if (_gameIds is EqualUnmodifiableListView) return _gameIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gameIds);
  }

  final List<String> _gameNames;
  @override
  @JsonKey(readValue: _readGameNames)
  List<String> get gameNames {
    if (_gameNames is EqualUnmodifiableListView) return _gameNames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gameNames);
  }

  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Event(id: $id, organizerId: $organizerId, organizerUsername: $organizerUsername, organizerDisplayName: $organizerDisplayName, organizerAvatarUrl: $organizerAvatarUrl, title: $title, description: $description, startTime: $startTime, endTime: $endTime, location: $location, locationDetails: $locationDetails, maxAttendees: $maxAttendees, attendeeCount: $attendeeCount, isAttending: $isAttending, myRsvp: $myRsvp, visibility: $visibility, status: $status, gameIds: $gameIds, gameNames: $gameNames, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.organizerId, organizerId) ||
                other.organizerId == organizerId) &&
            (identical(other.organizerUsername, organizerUsername) ||
                other.organizerUsername == organizerUsername) &&
            (identical(other.organizerDisplayName, organizerDisplayName) ||
                other.organizerDisplayName == organizerDisplayName) &&
            (identical(other.organizerAvatarUrl, organizerAvatarUrl) ||
                other.organizerAvatarUrl == organizerAvatarUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.locationDetails, locationDetails) ||
                other.locationDetails == locationDetails) &&
            (identical(other.maxAttendees, maxAttendees) ||
                other.maxAttendees == maxAttendees) &&
            (identical(other.attendeeCount, attendeeCount) ||
                other.attendeeCount == attendeeCount) &&
            (identical(other.isAttending, isAttending) ||
                other.isAttending == isAttending) &&
            (identical(other.myRsvp, myRsvp) || other.myRsvp == myRsvp) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._gameIds, _gameIds) &&
            const DeepCollectionEquality()
                .equals(other._gameNames, _gameNames) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        organizerId,
        organizerUsername,
        organizerDisplayName,
        organizerAvatarUrl,
        title,
        description,
        startTime,
        endTime,
        location,
        locationDetails,
        maxAttendees,
        attendeeCount,
        isAttending,
        myRsvp,
        visibility,
        status,
        const DeepCollectionEquality().hash(_gameIds),
        const DeepCollectionEquality().hash(_gameNames),
        createdAt
      ]);

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventImplCopyWith<_$EventImpl> get copyWith =>
      __$$EventImplCopyWithImpl<_$EventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EventImplToJson(
      this,
    );
  }
}

abstract class _Event implements Event {
  const factory _Event(
      {required final String id,
      @JsonKey(readValue: _readHostId) required final String organizerId,
      @JsonKey(readValue: _readHostUsername)
      required final String organizerUsername,
      @JsonKey(readValue: _readHostDisplayName)
      required final String organizerDisplayName,
      @JsonKey(readValue: _readHostAvatarUrl) final String? organizerAvatarUrl,
      required final String title,
      @JsonKey(defaultValue: '') required final String description,
      @JsonKey(name: 'scheduledAt') required final DateTime startTime,
      final DateTime? endTime,
      @JsonKey(defaultValue: '') required final String location,
      final String? locationDetails,
      @JsonKey(readValue: _readMaxParticipants) final int? maxAttendees,
      @JsonKey(name: 'participantCount') final int attendeeCount,
      @JsonKey(readValue: _readIsAttending) final bool isAttending,
      final String? myRsvp,
      final String? visibility,
      final String? status,
      @JsonKey(readValue: _readGameIds) final List<String> gameIds,
      @JsonKey(readValue: _readGameNames) final List<String> gameNames,
      required final DateTime createdAt}) = _$EventImpl;

  factory _Event.fromJson(Map<String, dynamic> json) = _$EventImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(readValue: _readHostId)
  String get organizerId;
  @override
  @JsonKey(readValue: _readHostUsername)
  String get organizerUsername;
  @override
  @JsonKey(readValue: _readHostDisplayName)
  String get organizerDisplayName;
  @override
  @JsonKey(readValue: _readHostAvatarUrl)
  String? get organizerAvatarUrl;
  @override
  String get title;
  @override
  @JsonKey(defaultValue: '')
  String get description;
  @override
  @JsonKey(name: 'scheduledAt')
  DateTime get startTime;
  @override
  DateTime? get endTime;
  @override
  @JsonKey(defaultValue: '')
  String get location;
  @override
  String? get locationDetails;
  @override
  @JsonKey(readValue: _readMaxParticipants)
  int? get maxAttendees;
  @override
  @JsonKey(name: 'participantCount')
  int get attendeeCount;
  @override
  @JsonKey(readValue: _readIsAttending)
  bool get isAttending;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | null.
  @override
  String? get myRsvp;

  /// `INVITE_ONLY` | `FRIENDS` | `PUBLIC`.
  @override
  String? get visibility;
  @override
  String? get status;
  @override
  @JsonKey(readValue: _readGameIds)
  List<String> get gameIds;
  @override
  @JsonKey(readValue: _readGameNames)
  List<String> get gameNames;
  @override
  DateTime get createdAt;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventImplCopyWith<_$EventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
