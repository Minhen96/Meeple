// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserGameImpl _$$UserGameImplFromJson(Map<String, dynamic> json) =>
    _$UserGameImpl(
      id: json['id'] as String,
      gameId: _readGameId(json, 'gameId') as String,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      isOwned: json['isOwned'] as bool? ?? false,
      isWishlisted: json['isWishlisted'] as bool? ?? false,
      isFavorited: json['isFavorited'] as bool? ?? false,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      personalRating: (json['personalRating'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$UserGameImplToJson(_$UserGameImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'game': instance.game,
      'isOwned': instance.isOwned,
      'isWishlisted': instance.isWishlisted,
      'isFavorited': instance.isFavorited,
      'playCount': instance.playCount,
      'personalRating': instance.personalRating,
      'notes': instance.notes,
    };
