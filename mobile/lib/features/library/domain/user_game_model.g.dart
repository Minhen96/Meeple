// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserGameImpl _$$UserGameImplFromJson(Map<String, dynamic> json) =>
    _$UserGameImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      gameId: json['gameId'] as String,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      isOwned: json['isOwned'] as bool? ?? false,
      isWishlisted: json['isWishlisted'] as bool? ?? false,
      isFavorited: json['isFavorited'] as bool? ?? false,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      personalRating: (json['personalRating'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.parse(json['lastPlayedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserGameImplToJson(_$UserGameImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'gameId': instance.gameId,
      'game': instance.game,
      'isOwned': instance.isOwned,
      'isWishlisted': instance.isWishlisted,
      'isFavorited': instance.isFavorited,
      'playCount': instance.playCount,
      'personalRating': instance.personalRating,
      'notes': instance.notes,
      'lastPlayedAt': instance.lastPlayedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
