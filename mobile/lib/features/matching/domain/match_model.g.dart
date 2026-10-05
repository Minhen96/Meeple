// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchRequestImpl _$$MatchRequestImplFromJson(Map<String, dynamic> json) =>
    _$MatchRequestImpl(
      id: json['id'] as String,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      availableFrom: json['availableFrom'] == null
          ? null
          : DateTime.parse(json['availableFrom'] as String),
      availableTo: json['availableTo'] == null
          ? null
          : DateTime.parse(json['availableTo'] as String),
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$MatchRequestImplToJson(_$MatchRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'game': instance.game,
      'availableFrom': instance.availableFrom?.toIso8601String(),
      'availableTo': instance.availableTo?.toIso8601String(),
      'status': instance.status,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_$MatchGroupImpl _$$MatchGroupImplFromJson(Map<String, dynamic> json) =>
    _$MatchGroupImpl(
      id: json['id'] as String,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      overlapStart: json['overlapStart'] == null
          ? null
          : DateTime.parse(json['overlapStart'] as String),
      overlapEnd: json['overlapEnd'] == null
          ? null
          : DateTime.parse(json['overlapEnd'] as String),
      status: json['status'] as String? ?? 'PENDING',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <UserSummary>[],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$MatchGroupImplToJson(_$MatchGroupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'game': instance.game,
      'overlapStart': instance.overlapStart?.toIso8601String(),
      'overlapEnd': instance.overlapEnd?.toIso8601String(),
      'status': instance.status,
      'members': instance.members,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
