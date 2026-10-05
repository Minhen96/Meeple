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
  UserSummary? get host => throw _privateConstructorUsedError;
  Game? get game => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  String? get locationDisplay => throw _privateConstructorUsedError;
  DateTime get scheduledAt => throw _privateConstructorUsedError;
  int get maxParticipants => throw _privateConstructorUsedError;
  int get participantCount => throw _privateConstructorUsedError;
  String get visibility => throw _privateConstructorUsedError;

  /// `OPEN` | `FULL` | `CANCELLED` | `COMPLETED` (FEATURES §4.4).
  String get status => throw _privateConstructorUsedError;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | `LEFT` | `KICKED` | null.
  String? get myRsvp => throw _privateConstructorUsedError;
  bool get isHost => throw _privateConstructorUsedError;
  List<EventParticipant> get participants => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

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
      UserSummary? host,
      Game? game,
      String title,
      String? description,
      String? location,
      String? locationDisplay,
      DateTime scheduledAt,
      int maxParticipants,
      int participantCount,
      String visibility,
      String status,
      String? myRsvp,
      bool isHost,
      List<EventParticipant> participants,
      DateTime? createdAt});

  $UserSummaryCopyWith<$Res>? get host;
  $GameCopyWith<$Res>? get game;
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
    Object? host = freezed,
    Object? game = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? locationDisplay = freezed,
    Object? scheduledAt = null,
    Object? maxParticipants = null,
    Object? participantCount = null,
    Object? visibility = null,
    Object? status = null,
    Object? myRsvp = freezed,
    Object? isHost = null,
    Object? participants = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as UserSummary?,
      game: freezed == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationDisplay: freezed == locationDisplay
          ? _value.locationDisplay
          : locationDisplay // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maxParticipants: null == maxParticipants
          ? _value.maxParticipants
          : maxParticipants // ignore: cast_nullable_to_non_nullable
              as int,
      participantCount: null == participantCount
          ? _value.participantCount
          : participantCount // ignore: cast_nullable_to_non_nullable
              as int,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      myRsvp: freezed == myRsvp
          ? _value.myRsvp
          : myRsvp // ignore: cast_nullable_to_non_nullable
              as String?,
      isHost: null == isHost
          ? _value.isHost
          : isHost // ignore: cast_nullable_to_non_nullable
              as bool,
      participants: null == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<EventParticipant>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserSummaryCopyWith<$Res>? get host {
    if (_value.host == null) {
      return null;
    }

    return $UserSummaryCopyWith<$Res>(_value.host!, (value) {
      return _then(_value.copyWith(host: value) as $Val);
    });
  }

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameCopyWith<$Res>? get game {
    if (_value.game == null) {
      return null;
    }

    return $GameCopyWith<$Res>(_value.game!, (value) {
      return _then(_value.copyWith(game: value) as $Val);
    });
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
      UserSummary? host,
      Game? game,
      String title,
      String? description,
      String? location,
      String? locationDisplay,
      DateTime scheduledAt,
      int maxParticipants,
      int participantCount,
      String visibility,
      String status,
      String? myRsvp,
      bool isHost,
      List<EventParticipant> participants,
      DateTime? createdAt});

  @override
  $UserSummaryCopyWith<$Res>? get host;
  @override
  $GameCopyWith<$Res>? get game;
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
    Object? host = freezed,
    Object? game = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? locationDisplay = freezed,
    Object? scheduledAt = null,
    Object? maxParticipants = null,
    Object? participantCount = null,
    Object? visibility = null,
    Object? status = null,
    Object? myRsvp = freezed,
    Object? isHost = null,
    Object? participants = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$EventImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as UserSummary?,
      game: freezed == game
          ? _value.game
          : game // ignore: cast_nullable_to_non_nullable
              as Game?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationDisplay: freezed == locationDisplay
          ? _value.locationDisplay
          : locationDisplay // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maxParticipants: null == maxParticipants
          ? _value.maxParticipants
          : maxParticipants // ignore: cast_nullable_to_non_nullable
              as int,
      participantCount: null == participantCount
          ? _value.participantCount
          : participantCount // ignore: cast_nullable_to_non_nullable
              as int,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      myRsvp: freezed == myRsvp
          ? _value.myRsvp
          : myRsvp // ignore: cast_nullable_to_non_nullable
              as String?,
      isHost: null == isHost
          ? _value.isHost
          : isHost // ignore: cast_nullable_to_non_nullable
              as bool,
      participants: null == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<EventParticipant>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EventImpl extends _Event {
  const _$EventImpl(
      {required this.id,
      this.host,
      this.game,
      this.title = '',
      this.description,
      this.location,
      this.locationDisplay,
      required this.scheduledAt,
      this.maxParticipants = 0,
      this.participantCount = 0,
      this.visibility = 'INVITE_ONLY',
      this.status = 'OPEN',
      this.myRsvp,
      this.isHost = false,
      final List<EventParticipant> participants = const <EventParticipant>[],
      this.createdAt})
      : _participants = participants,
        super._();

  factory _$EventImpl.fromJson(Map<String, dynamic> json) =>
      _$$EventImplFromJson(json);

  @override
  final String id;
  @override
  final UserSummary? host;
  @override
  final Game? game;
  @override
  @JsonKey()
  final String title;
  @override
  final String? description;
  @override
  final String? location;
  @override
  final String? locationDisplay;
  @override
  final DateTime scheduledAt;
  @override
  @JsonKey()
  final int maxParticipants;
  @override
  @JsonKey()
  final int participantCount;
  @override
  @JsonKey()
  final String visibility;

  /// `OPEN` | `FULL` | `CANCELLED` | `COMPLETED` (FEATURES §4.4).
  @override
  @JsonKey()
  final String status;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | `LEFT` | `KICKED` | null.
  @override
  final String? myRsvp;
  @override
  @JsonKey()
  final bool isHost;
  final List<EventParticipant> _participants;
  @override
  @JsonKey()
  List<EventParticipant> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Event(id: $id, host: $host, game: $game, title: $title, description: $description, location: $location, locationDisplay: $locationDisplay, scheduledAt: $scheduledAt, maxParticipants: $maxParticipants, participantCount: $participantCount, visibility: $visibility, status: $status, myRsvp: $myRsvp, isHost: $isHost, participants: $participants, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.game, game) || other.game == game) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.locationDisplay, locationDisplay) ||
                other.locationDisplay == locationDisplay) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.maxParticipants, maxParticipants) ||
                other.maxParticipants == maxParticipants) &&
            (identical(other.participantCount, participantCount) ||
                other.participantCount == participantCount) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.myRsvp, myRsvp) || other.myRsvp == myRsvp) &&
            (identical(other.isHost, isHost) || other.isHost == isHost) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      host,
      game,
      title,
      description,
      location,
      locationDisplay,
      scheduledAt,
      maxParticipants,
      participantCount,
      visibility,
      status,
      myRsvp,
      isHost,
      const DeepCollectionEquality().hash(_participants),
      createdAt);

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

abstract class _Event extends Event {
  const factory _Event(
      {required final String id,
      final UserSummary? host,
      final Game? game,
      final String title,
      final String? description,
      final String? location,
      final String? locationDisplay,
      required final DateTime scheduledAt,
      final int maxParticipants,
      final int participantCount,
      final String visibility,
      final String status,
      final String? myRsvp,
      final bool isHost,
      final List<EventParticipant> participants,
      final DateTime? createdAt}) = _$EventImpl;
  const _Event._() : super._();

  factory _Event.fromJson(Map<String, dynamic> json) = _$EventImpl.fromJson;

  @override
  String get id;
  @override
  UserSummary? get host;
  @override
  Game? get game;
  @override
  String get title;
  @override
  String? get description;
  @override
  String? get location;
  @override
  String? get locationDisplay;
  @override
  DateTime get scheduledAt;
  @override
  int get maxParticipants;
  @override
  int get participantCount;
  @override
  String get visibility;

  /// `OPEN` | `FULL` | `CANCELLED` | `COMPLETED` (FEATURES §4.4).
  @override
  String get status;

  /// `ACCEPTED` | `DECLINED` | `INVITED` | `LEFT` | `KICKED` | null.
  @override
  String? get myRsvp;
  @override
  bool get isHost;
  @override
  List<EventParticipant> get participants;
  @override
  DateTime? get createdAt;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventImplCopyWith<_$EventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EventParticipant _$EventParticipantFromJson(Map<String, dynamic> json) {
  return _EventParticipant.fromJson(json);
}

/// @nodoc
mixin _$EventParticipant {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  @JsonKey(readValue: _readDisplayName)
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this EventParticipant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EventParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventParticipantCopyWith<EventParticipant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventParticipantCopyWith<$Res> {
  factory $EventParticipantCopyWith(
          EventParticipant value, $Res Function(EventParticipant) then) =
      _$EventParticipantCopyWithImpl<$Res, EventParticipant>;
  @useResult
  $Res call(
      {String id,
      String username,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      String status});
}

/// @nodoc
class _$EventParticipantCopyWithImpl<$Res, $Val extends EventParticipant>
    implements $EventParticipantCopyWith<$Res> {
  _$EventParticipantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EventParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? status = null,
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EventParticipantImplCopyWith<$Res>
    implements $EventParticipantCopyWith<$Res> {
  factory _$$EventParticipantImplCopyWith(_$EventParticipantImpl value,
          $Res Function(_$EventParticipantImpl) then) =
      __$$EventParticipantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      @JsonKey(readValue: _readDisplayName) String displayName,
      String? avatarUrl,
      String status});
}

/// @nodoc
class __$$EventParticipantImplCopyWithImpl<$Res>
    extends _$EventParticipantCopyWithImpl<$Res, _$EventParticipantImpl>
    implements _$$EventParticipantImplCopyWith<$Res> {
  __$$EventParticipantImplCopyWithImpl(_$EventParticipantImpl _value,
      $Res Function(_$EventParticipantImpl) _then)
      : super(_value, _then);

  /// Create a copy of EventParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? status = null,
  }) {
    return _then(_$EventParticipantImpl(
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EventParticipantImpl extends _EventParticipant {
  const _$EventParticipantImpl(
      {required this.id,
      this.username = '',
      @JsonKey(readValue: _readDisplayName) this.displayName = '',
      this.avatarUrl,
      this.status = 'ACCEPTED'})
      : super._();

  factory _$EventParticipantImpl.fromJson(Map<String, dynamic> json) =>
      _$$EventParticipantImplFromJson(json);

  @override
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
  @JsonKey()
  final String status;

  @override
  String toString() {
    return 'EventParticipant(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventParticipantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, username, displayName, avatarUrl, status);

  /// Create a copy of EventParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventParticipantImplCopyWith<_$EventParticipantImpl> get copyWith =>
      __$$EventParticipantImplCopyWithImpl<_$EventParticipantImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EventParticipantImplToJson(
      this,
    );
  }
}

abstract class _EventParticipant extends EventParticipant {
  const factory _EventParticipant(
      {required final String id,
      final String username,
      @JsonKey(readValue: _readDisplayName) final String displayName,
      final String? avatarUrl,
      final String status}) = _$EventParticipantImpl;
  const _EventParticipant._() : super._();

  factory _EventParticipant.fromJson(Map<String, dynamic> json) =
      _$EventParticipantImpl.fromJson;

  @override
  String get id;
  @override
  String get username;
  @override
  @JsonKey(readValue: _readDisplayName)
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String get status;

  /// Create a copy of EventParticipant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventParticipantImplCopyWith<_$EventParticipantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EventDraft {
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  DateTime get scheduledAt => throw _privateConstructorUsedError;
  String? get gameId => throw _privateConstructorUsedError;
  int? get maxParticipants => throw _privateConstructorUsedError;
  EventVisibility get visibility => throw _privateConstructorUsedError;
  List<String> get invitedUserIds => throw _privateConstructorUsedError;

  /// Create a copy of EventDraft
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventDraftCopyWith<EventDraft> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventDraftCopyWith<$Res> {
  factory $EventDraftCopyWith(
          EventDraft value, $Res Function(EventDraft) then) =
      _$EventDraftCopyWithImpl<$Res, EventDraft>;
  @useResult
  $Res call(
      {String title,
      String? description,
      String? location,
      DateTime scheduledAt,
      String? gameId,
      int? maxParticipants,
      EventVisibility visibility,
      List<String> invitedUserIds});
}

/// @nodoc
class _$EventDraftCopyWithImpl<$Res, $Val extends EventDraft>
    implements $EventDraftCopyWith<$Res> {
  _$EventDraftCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EventDraft
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? scheduledAt = null,
    Object? gameId = freezed,
    Object? maxParticipants = freezed,
    Object? visibility = null,
    Object? invitedUserIds = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      gameId: freezed == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxParticipants: freezed == maxParticipants
          ? _value.maxParticipants
          : maxParticipants // ignore: cast_nullable_to_non_nullable
              as int?,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as EventVisibility,
      invitedUserIds: null == invitedUserIds
          ? _value.invitedUserIds
          : invitedUserIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EventDraftImplCopyWith<$Res>
    implements $EventDraftCopyWith<$Res> {
  factory _$$EventDraftImplCopyWith(
          _$EventDraftImpl value, $Res Function(_$EventDraftImpl) then) =
      __$$EventDraftImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      String? description,
      String? location,
      DateTime scheduledAt,
      String? gameId,
      int? maxParticipants,
      EventVisibility visibility,
      List<String> invitedUserIds});
}

/// @nodoc
class __$$EventDraftImplCopyWithImpl<$Res>
    extends _$EventDraftCopyWithImpl<$Res, _$EventDraftImpl>
    implements _$$EventDraftImplCopyWith<$Res> {
  __$$EventDraftImplCopyWithImpl(
      _$EventDraftImpl _value, $Res Function(_$EventDraftImpl) _then)
      : super(_value, _then);

  /// Create a copy of EventDraft
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? description = freezed,
    Object? location = freezed,
    Object? scheduledAt = null,
    Object? gameId = freezed,
    Object? maxParticipants = freezed,
    Object? visibility = null,
    Object? invitedUserIds = null,
  }) {
    return _then(_$EventDraftImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      gameId: freezed == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxParticipants: freezed == maxParticipants
          ? _value.maxParticipants
          : maxParticipants // ignore: cast_nullable_to_non_nullable
              as int?,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as EventVisibility,
      invitedUserIds: null == invitedUserIds
          ? _value._invitedUserIds
          : invitedUserIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$EventDraftImpl extends _EventDraft {
  const _$EventDraftImpl(
      {required this.title,
      this.description,
      this.location,
      required this.scheduledAt,
      this.gameId,
      this.maxParticipants,
      this.visibility = EventVisibility.inviteOnly,
      final List<String> invitedUserIds = const <String>[]})
      : _invitedUserIds = invitedUserIds,
        super._();

  @override
  final String title;
  @override
  final String? description;
  @override
  final String? location;
  @override
  final DateTime scheduledAt;
  @override
  final String? gameId;
  @override
  final int? maxParticipants;
  @override
  @JsonKey()
  final EventVisibility visibility;
  final List<String> _invitedUserIds;
  @override
  @JsonKey()
  List<String> get invitedUserIds {
    if (_invitedUserIds is EqualUnmodifiableListView) return _invitedUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_invitedUserIds);
  }

  @override
  String toString() {
    return 'EventDraft(title: $title, description: $description, location: $location, scheduledAt: $scheduledAt, gameId: $gameId, maxParticipants: $maxParticipants, visibility: $visibility, invitedUserIds: $invitedUserIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventDraftImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.maxParticipants, maxParticipants) ||
                other.maxParticipants == maxParticipants) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            const DeepCollectionEquality()
                .equals(other._invitedUserIds, _invitedUserIds));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      description,
      location,
      scheduledAt,
      gameId,
      maxParticipants,
      visibility,
      const DeepCollectionEquality().hash(_invitedUserIds));

  /// Create a copy of EventDraft
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventDraftImplCopyWith<_$EventDraftImpl> get copyWith =>
      __$$EventDraftImplCopyWithImpl<_$EventDraftImpl>(this, _$identity);
}

abstract class _EventDraft extends EventDraft {
  const factory _EventDraft(
      {required final String title,
      final String? description,
      final String? location,
      required final DateTime scheduledAt,
      final String? gameId,
      final int? maxParticipants,
      final EventVisibility visibility,
      final List<String> invitedUserIds}) = _$EventDraftImpl;
  const _EventDraft._() : super._();

  @override
  String get title;
  @override
  String? get description;
  @override
  String? get location;
  @override
  DateTime get scheduledAt;
  @override
  String? get gameId;
  @override
  int? get maxParticipants;
  @override
  EventVisibility get visibility;
  @override
  List<String> get invitedUserIds;

  /// Create a copy of EventDraft
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventDraftImplCopyWith<_$EventDraftImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
