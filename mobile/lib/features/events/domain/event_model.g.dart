// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EventImpl _$$EventImplFromJson(Map<String, dynamic> json) => _$EventImpl(
      id: json['id'] as String,
      host: json['host'] == null
          ? null
          : UserSummary.fromJson(json['host'] as Map<String, dynamic>),
      game: json['game'] == null
          ? null
          : Game.fromJson(json['game'] as Map<String, dynamic>),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      locationDisplay: json['locationDisplay'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 0,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      visibility: json['visibility'] as String? ?? 'INVITE_ONLY',
      status: json['status'] as String? ?? 'OPEN',
      myRsvp: json['myRsvp'] as String?,
      isHost: json['isHost'] as bool? ?? false,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => EventParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EventParticipant>[],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$EventImplToJson(_$EventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'host': instance.host,
      'game': instance.game,
      'title': instance.title,
      'description': instance.description,
      'location': instance.location,
      'locationDisplay': instance.locationDisplay,
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'maxParticipants': instance.maxParticipants,
      'participantCount': instance.participantCount,
      'visibility': instance.visibility,
      'status': instance.status,
      'myRsvp': instance.myRsvp,
      'isHost': instance.isHost,
      'participants': instance.participants,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_$EventParticipantImpl _$$EventParticipantImplFromJson(
        Map<String, dynamic> json) =>
    _$EventParticipantImpl(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      displayName: _readDisplayName(json, 'displayName') as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String? ?? 'ACCEPTED',
    );

Map<String, dynamic> _$$EventParticipantImplToJson(
        _$EventParticipantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'status': instance.status,
    };
