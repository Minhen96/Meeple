// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameImpl _$$GameImplFromJson(Map<String, dynamic> json) => _$GameImpl(
      id: json['id'] as String,
      name: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      yearPublished: (json['yearPublished'] as num?)?.toInt(),
      minPlayers: (json['minPlayers'] as num?)?.toInt(),
      maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
      minAge: (json['minAge'] as num?)?.toInt(),
      minPlayTimeMinutes: (json['playTime'] as num?)?.toInt(),
      maxPlayTimeMinutes:
          (_readPlayTime(json, 'maxPlayTimeMinutes') as num?)?.toInt(),
      averageRating: (json['bggRating'] as num?)?.toDouble(),
      complexity: (json['complexityWeight'] as num?)?.toDouble(),
      rank: (json['rank'] as num?)?.toInt(),
      bggId: (json['bggId'] as num?)?.toInt(),
      bggUrl: json['bggUrl'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mechanics: (json['mechanics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      designers: (json['designers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      publishers: (json['publishers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      hasRulebook: json['hasRulebook'] as bool? ?? false,
      friendAvgRating: (json['friendAvgRating'] as num?)?.toDouble(),
      friendRatingCount: (json['friendRatingCount'] as num?)?.toInt() ?? 0,
      ownedByFriends: (json['ownedByFriends'] as List<dynamic>?)
              ?.map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <UserSummary>[],
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
      'minAge': instance.minAge,
      'playTime': instance.minPlayTimeMinutes,
      'maxPlayTimeMinutes': instance.maxPlayTimeMinutes,
      'bggRating': instance.averageRating,
      'complexityWeight': instance.complexity,
      'rank': instance.rank,
      'bggId': instance.bggId,
      'bggUrl': instance.bggUrl,
      'categories': instance.categories,
      'mechanics': instance.mechanics,
      'designers': instance.designers,
      'publishers': instance.publishers,
      'hasRulebook': instance.hasRulebook,
      'friendAvgRating': instance.friendAvgRating,
      'friendRatingCount': instance.friendRatingCount,
      'ownedByFriends': instance.ownedByFriends,
    };
