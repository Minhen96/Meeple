// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EventImpl _$$EventImplFromJson(Map<String, dynamic> json) => _$EventImpl(
      id: json['id'] as String,
      organizerId: _readHostId(json, 'organizerId') as String,
      organizerUsername: _readHostUsername(json, 'organizerUsername') as String,
      organizerDisplayName:
          _readHostDisplayName(json, 'organizerDisplayName') as String,
      organizerAvatarUrl:
          _readHostAvatarUrl(json, 'organizerAvatarUrl') as String?,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      startTime: DateTime.parse(json['scheduledAt'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      location: json['location'] as String? ?? '',
      locationDetails: json['locationDetails'] as String?,
      maxAttendees:
          (_readMaxParticipants(json, 'maxAttendees') as num?)?.toInt(),
      attendeeCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      isAttending: _readIsAttending(json, 'isAttending') as bool? ?? false,
      myRsvp: json['myRsvp'] as String?,
      visibility: json['visibility'] as String?,
      status: json['status'] as String?,
      gameIds: (_readGameIds(json, 'gameIds') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      gameNames: (_readGameNames(json, 'gameNames') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$EventImplToJson(_$EventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organizerId': instance.organizerId,
      'organizerUsername': instance.organizerUsername,
      'organizerDisplayName': instance.organizerDisplayName,
      'organizerAvatarUrl': instance.organizerAvatarUrl,
      'title': instance.title,
      'description': instance.description,
      'scheduledAt': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'location': instance.location,
      'locationDetails': instance.locationDetails,
      'maxAttendees': instance.maxAttendees,
      'participantCount': instance.attendeeCount,
      'isAttending': instance.isAttending,
      'myRsvp': instance.myRsvp,
      'visibility': instance.visibility,
      'status': instance.status,
      'gameIds': instance.gameIds,
      'gameNames': instance.gameNames,
      'createdAt': instance.createdAt.toIso8601String(),
    };
