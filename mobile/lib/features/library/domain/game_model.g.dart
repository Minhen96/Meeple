// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameImpl _$$GameImplFromJson(Map<String, dynamic> json) => _$GameImpl(
      id: json['id'] as String,
      name: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      yearPublished: (json['yearPublished'] as num?)?.toInt(),
      minPlayers: (json['minPlayers'] as num?)?.toInt(),
      maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
      minPlayTimeMinutes: (json['playTime'] as num?)?.toInt(),
      maxPlayTimeMinutes:
          (_readPlayTime(json, 'maxPlayTimeMinutes') as num?)?.toInt(),
      averageRating: (json['bggRating'] as num?)?.toDouble(),
      complexity: (json['complexityWeight'] as num?)?.toDouble(),
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
      hasRulebook: json['hasRulebook'] as bool? ?? false,
    );

Map<String, dynamic> _$$GameImplToJson(_$GameImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'yearPublished': instance.yearPublished,
      'minPlayers': instance.minPlayers,
      'maxPlayers': instance.maxPlayers,
      'playTime': instance.minPlayTimeMinutes,
      'maxPlayTimeMinutes': instance.maxPlayTimeMinutes,
      'bggRating': instance.averageRating,
      'complexityWeight': instance.complexity,
      'bggId': instance.bggId,
      'bggUrl': instance.bggUrl,
      'categories': instance.categories,
      'mechanics': instance.mechanics,
      'designers': instance.designers,
      'hasRulebook': instance.hasRulebook,
    };
