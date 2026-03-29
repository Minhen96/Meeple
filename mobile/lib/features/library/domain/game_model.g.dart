// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameImpl _$$GameImplFromJson(Map<String, dynamic> json) => _$GameImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      minPlayers: (json['minPlayers'] as num?)?.toInt(),
      maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
      minPlayTimeMinutes: (json['minPlayTimeMinutes'] as num?)?.toInt(),
      maxPlayTimeMinutes: (json['maxPlayTimeMinutes'] as num?)?.toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      bggId: (json['bggId'] as num?)?.toInt(),
      bggUrl: json['bggUrl'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      mechanics: (json['mechanics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      designers: (json['designers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$GameImplToJson(_$GameImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'minPlayers': instance.minPlayers,
      'maxPlayers': instance.maxPlayers,
      'minPlayTimeMinutes': instance.minPlayTimeMinutes,
      'maxPlayTimeMinutes': instance.maxPlayTimeMinutes,
      'averageRating': instance.averageRating,
      'bggId': instance.bggId,
      'bggUrl': instance.bggUrl,
      'categories': instance.categories,
      'mechanics': instance.mechanics,
      'designers': instance.designers,
    };
