// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostImpl _$$PostImplFromJson(Map<String, dynamic> json) => _$PostImpl(
      id: json['id'] as String,
      authorId: _readAuthorId(json, 'authorId') as String,
      authorUsername: _readAuthorUsername(json, 'authorUsername') as String,
      authorDisplayName:
          _readAuthorDisplayName(json, 'authorDisplayName') as String,
      authorAvatarUrl: _readAuthorAvatarUrl(json, 'authorAvatarUrl') as String?,
      content: json['caption'] as String? ?? '',
      location: json['location'] as String?,
      playedAt: json['playedAt'] == null
          ? null
          : DateTime.parse(json['playedAt'] as String),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      taggedGameId: _readGameId(json, 'taggedGameId') as String?,
      taggedGameName: _readGameTitle(json, 'taggedGameName') as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['likedByMe'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$PostImplToJson(_$PostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'authorUsername': instance.authorUsername,
      'authorDisplayName': instance.authorDisplayName,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'caption': instance.content,
      'location': instance.location,
      'playedAt': instance.playedAt?.toIso8601String(),
      'imageUrls': instance.imageUrls,
      'taggedGameId': instance.taggedGameId,
      'taggedGameName': instance.taggedGameName,
      'likeCount': instance.likeCount,
      'commentCount': instance.commentCount,
      'likedByMe': instance.isLikedByMe,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$CommentImpl _$$CommentImplFromJson(Map<String, dynamic> json) =>
    _$CommentImpl(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorUsername: json['authorUsername'] as String,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      content: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CommentImplToJson(_$CommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'authorUsername': instance.authorUsername,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'body': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
    };
