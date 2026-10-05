// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

/// An event (`EventResponse`). Host and game fields are flattened from the
/// nested `host` / `game` objects.
@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    @JsonKey(readValue: _readHostId) required String organizerId,
    @JsonKey(readValue: _readHostUsername) required String organizerUsername,
    @JsonKey(readValue: _readHostDisplayName)
    required String organizerDisplayName,
    @JsonKey(readValue: _readHostAvatarUrl) String? organizerAvatarUrl,
    required String title,
    @JsonKey(defaultValue: '') required String description,
    @JsonKey(name: 'scheduledAt') required DateTime startTime,
    DateTime? endTime,
    @JsonKey(defaultValue: '') required String location,
    String? locationDetails,
    @JsonKey(readValue: _readMaxParticipants) int? maxAttendees,
    @JsonKey(name: 'participantCount') @Default(0) int attendeeCount,
    @JsonKey(readValue: _readIsAttending) @Default(false) bool isAttending,

    /// `ACCEPTED` | `DECLINED` | `INVITED` | null.
    String? myRsvp,

    /// `INVITE_ONLY` | `FRIENDS` | `PUBLIC`.
    String? visibility,
    String? status,
    @JsonKey(readValue: _readGameIds) @Default([]) List<String> gameIds,
    @JsonKey(readValue: _readGameNames) @Default([]) List<String> gameNames,
    required DateTime createdAt,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}

Object? _host(Map<dynamic, dynamic> json, String field) =>
    (json['host'] as Map?)?[field];

Object? _readHostId(Map<dynamic, dynamic> json, String key) =>
    _host(json, 'id');
Object? _readHostUsername(Map<dynamic, dynamic> json, String key) =>
    _host(json, 'username');
Object? _readHostDisplayName(Map<dynamic, dynamic> json, String key) =>
    _host(json, 'displayName') ?? _host(json, 'username');
Object? _readHostAvatarUrl(Map<dynamic, dynamic> json, String key) =>
    _host(json, 'avatarUrl');

/// Every backend event has a limit (default 8); non-positive values are
/// treated as unlimited defensively.
Object? _readMaxParticipants(Map<dynamic, dynamic> json, String key) {
  final value = json['maxParticipants'];
  return value is num && value > 0 ? value : null;
}

Object? _readIsAttending(Map<dynamic, dynamic> json, String key) =>
    json['myRsvp'] == 'ACCEPTED';

Object? _readGameIds(Map<dynamic, dynamic> json, String key) {
  final id = (json['game'] as Map?)?['id'];
  return id == null ? const <Object?>[] : <Object?>[id];
}

Object? _readGameNames(Map<dynamic, dynamic> json, String key) {
  final title = (json['game'] as Map?)?['title'];
  return title == null ? const <Object?>[] : <Object?>[title];
}
