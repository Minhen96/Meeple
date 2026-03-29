// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EventImpl _$$EventImplFromJson(Map<String, dynamic> json) => _$EventImpl(
      id: json['id'] as String,
      organizerId: json['organizerId'] as String,
      organizerUsername: json['organizerUsername'] as String,
      organizerDisplayName: json['organizerDisplayName'] as String,
      organizerAvatarUrl: json['organizerAvatarUrl'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      location: json['location'] as String,
      locationDetails: json['locationDetails'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      maxAttendees: (json['maxAttendees'] as num?)?.toInt(),
      attendeeCount: (json['attendeeCount'] as num?)?.toInt() ?? 0,
      isAttending: json['isAttending'] as bool? ?? false,
      gameIds: (json['gameIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      gameNames: (json['gameNames'] as List<dynamic>?)
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
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'location': instance.location,
      'locationDetails': instance.locationDetails,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'maxAttendees': instance.maxAttendees,
      'attendeeCount': instance.attendeeCount,
      'isAttending': instance.isAttending,
      'gameIds': instance.gameIds,
      'gameNames': instance.gameNames,
      'createdAt': instance.createdAt.toIso8601String(),
    };
