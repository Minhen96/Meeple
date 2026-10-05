// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

/// Event visibility chosen at creation (FEATURES §0; default invite-only).
enum EventVisibility {
  inviteOnly('INVITE_ONLY'),
  friends('FRIENDS'),
  public('PUBLIC');

  const EventVisibility(this.wire);

  final String wire;

  static EventVisibility parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => EventVisibility.inviteOnly,
      );
}

/// Lists of `GET /events?scope=` (GAP §6.1 [WP2]).
enum EventScope {
  upcoming('upcoming'),
  past('past'),
  mine('mine');

  const EventScope(this.wire);

  final String wire;
}

/// An event (`EventResponse` incl. the GAP §6.1 [WP2] additions); also
/// parses search `EventSummary`s, whose missing fields take defaults.
@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    UserSummary? host,
    Game? game,
    @Default('') String title,
    String? description,
    String? location,
    String? locationDisplay,
    required DateTime scheduledAt,
    @Default(0) int maxParticipants,
    @Default(0) int participantCount,
    @Default('INVITE_ONLY') String visibility,

    /// `OPEN` | `FULL` | `CANCELLED` | `COMPLETED` (FEATURES §4.4).
    @Default('OPEN') String status,

    /// `ACCEPTED` | `DECLINED` | `INVITED` | `LEFT` | `KICKED` | null.
    String? myRsvp,
    @Default(false) bool isHost,
    @Default(<EventParticipant>[]) List<EventParticipant> participants,
    DateTime? createdAt,
  }) = _Event;

  const Event._();

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  bool get isCancelled => status == 'CANCELLED';
  bool get isCompleted =>
      status == 'COMPLETED' ||
      (!isCancelled && scheduledAt.isBefore(DateTime.now()));
  bool get isAttending => myRsvp == 'ACCEPTED';
  bool get isInvited => myRsvp == 'INVITED';
  bool get hasDeclined => myRsvp == 'DECLINED';
  bool get isFull =>
      status == 'FULL' ||
      (maxParticipants > 0 && participantCount >= maxParticipants);

  /// Location as shown to the viewer (`locationDisplay` may hide the exact
  /// address from non-participants).
  String? get displayLocation {
    final shown = locationDisplay ?? location;
    return shown == null || shown.isEmpty ? null : shown;
  }

  EventVisibility get visibilityValue => EventVisibility.parse(visibility);

  List<EventParticipant> get acceptedParticipants =>
      participants.where((p) => p.status == 'ACCEPTED').toList();
}

/// `participants: [{id, username, displayName, avatarUrl, status}]`.
@freezed
class EventParticipant with _$EventParticipant {
  const factory EventParticipant({
    required String id,
    @Default('') String username,
    @JsonKey(readValue: _readDisplayName) @Default('') String displayName,
    String? avatarUrl,
    @Default('ACCEPTED') String status,
  }) = _EventParticipant;

  const EventParticipant._();

  factory EventParticipant.fromJson(Map<String, dynamic> json) =>
      _$EventParticipantFromJson(json);

  UserSummary get asUser => UserSummary(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
}

Object? _readDisplayName(Map<dynamic, dynamic> json, String key) {
  final name = json['displayName'];
  return name is String && name.isNotEmpty ? name : json['username'];
}

/// Form values of create/edit event (`CreateEventRequest` /
/// `UpdateEventRequest`).
@freezed
class EventDraft with _$EventDraft {
  const factory EventDraft({
    required String title,
    String? description,
    String? location,
    required DateTime scheduledAt,
    String? gameId,
    int? maxParticipants,
    @Default(EventVisibility.inviteOnly) EventVisibility visibility,
    @Default(<String>[]) List<String> invitedUserIds,
  }) = _EventDraft;

  const EventDraft._();

  Map<String, dynamic> toRequest({bool includeInvites = true}) => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (location != null && location!.isNotEmpty) 'location': location,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (gameId != null) 'gameId': gameId,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        'visibility': visibility.wire,
        if (includeInvites && invitedUserIds.isNotEmpty)
          'invitedUserIds': invitedUserIds,
      };
}
