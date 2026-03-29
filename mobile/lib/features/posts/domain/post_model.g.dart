// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostImpl _$$PostImplFromJson(Map<String, dynamic> json) => _$PostImpl(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorUsername: json['authorUsername'] as String,
      authorDisplayName: json['authorDisplayName'] as String,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      content: json['content'] as String,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      taggedGameId: json['taggedGameId'] as String?,
      taggedGameName: json['taggedGameName'] as String?,
      linkedEventId: json['linkedEventId'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PostImplToJson(_$PostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'authorUsername': instance.authorUsername,
      'authorDisplayName': instance.authorDisplayName,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'content': instance.content,
      'imageUrls': instance.imageUrls,
      'taggedGameId': instance.taggedGameId,
      'taggedGameName': instance.taggedGameName,
      'linkedEventId': instance.linkedEventId,
      'likeCount': instance.likeCount,
      'commentCount': instance.commentCount,
      'isLikedByMe': instance.isLikedByMe,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$CommentImpl _$$CommentImplFromJson(Map<String, dynamic> json) =>
    _$CommentImpl(
      id: json['id'] as String,
      postId: json['postId'] as String,
      authorId: json['authorId'] as String,
      authorUsername: json['authorUsername'] as String,
      authorDisplayName: json['authorDisplayName'] as String,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      content: json['content'] as String,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CommentImplToJson(_$CommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'postId': instance.postId,
      'authorId': instance.authorId,
      'authorUsername': instance.authorUsername,
      'authorDisplayName': instance.authorDisplayName,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'content': instance.content,
      'likeCount': instance.likeCount,
      'isLikedByMe': instance.isLikedByMe,
      'createdAt': instance.createdAt.toIso8601String(),
    };
