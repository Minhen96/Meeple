// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendRequestImpl _$$FriendRequestImplFromJson(Map<String, dynamic> json) =>
    _$FriendRequestImpl(
      id: json['id'] as String,
      sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
      receiver: UserSummary.fromJson(json['receiver'] as Map<String, dynamic>),
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$FriendRequestImplToJson(_$FriendRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'receiver': instance.receiver,
      'status': instance.status,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_$UserStatsImpl _$$UserStatsImplFromJson(Map<String, dynamic> json) =>
    _$UserStatsImpl(
      gamesOwned: (json['gamesOwned'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      friends: (json['friends'] as num?)?.toInt() ?? 0,
      mostPlayedGame: json['mostPlayedGame'] == null
          ? null
          : MostPlayedGame.fromJson(
              json['mostPlayedGame'] as Map<String, dynamic>),
      favoriteCategory: json['favoriteCategory'] as String?,
      mostPlayedWith: json['mostPlayedWith'] == null
          ? null
          : MostPlayedWith.fromJson(
              json['mostPlayedWith'] as Map<String, dynamic>),
      totalPlayMinutes: (json['totalPlayMinutes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$UserStatsImplToJson(_$UserStatsImpl instance) =>
    <String, dynamic>{
      'gamesOwned': instance.gamesOwned,
      'sessions': instance.sessions,
      'friends': instance.friends,
      'mostPlayedGame': instance.mostPlayedGame,
      'favoriteCategory': instance.favoriteCategory,
      'mostPlayedWith': instance.mostPlayedWith,
      'totalPlayMinutes': instance.totalPlayMinutes,
    };

_$MostPlayedGameImpl _$$MostPlayedGameImplFromJson(Map<String, dynamic> json) =>
    _$MostPlayedGameImpl(
      gameId: json['gameId'] as String,
      title: json['title'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$MostPlayedGameImplToJson(
        _$MostPlayedGameImpl instance) =>
    <String, dynamic>{
      'gameId': instance.gameId,
      'title': instance.title,
      'playCount': instance.playCount,
    };

_$MostPlayedWithImpl _$$MostPlayedWithImplFromJson(Map<String, dynamic> json) =>
    _$MostPlayedWithImpl(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? '',
      sharedSessions: (json['sharedSessions'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$MostPlayedWithImplToJson(
        _$MostPlayedWithImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'displayName': instance.displayName,
      'sharedSessions': instance.sharedSessions,
    };
