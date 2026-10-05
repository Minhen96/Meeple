// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostImpl _$$PostImplFromJson(Map<String, dynamic> json) => _$PostImpl(
      id: json['id'] as String,
      author: UserSummary.fromJson(
          readUserOrDeleted(json, 'author') as Map<String, dynamic>),
      caption: json['caption'] as String? ?? '',
      location: json['location'] as String?,
      playedAt: json['playedAt'] == null
          ? null
          : DateTime.parse(json['playedAt'] as String),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      game: json['game'] == null
          ? null
          : Game.fromJson(json['game'] as Map<String, dynamic>),
      taggedUsers: (json['taggedUsers'] as List<dynamic>?)
              ?.map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <UserSummary>[],
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      eventId: json['eventId'] as String?,
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$PostImplToJson(_$PostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author': instance.author,
      'caption': instance.caption,
      'location': instance.location,
      'playedAt': instance.playedAt?.toIso8601String(),
      'imageUrls': instance.imageUrls,
      'game': instance.game,
      'taggedUsers': instance.taggedUsers,
      'likeCount': instance.likeCount,
      'commentCount': instance.commentCount,
      'likedByMe': instance.likedByMe,
      'isBookmarked': instance.isBookmarked,
      'eventId': instance.eventId,
      'editedAt': instance.editedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$CommentImpl _$$CommentImplFromJson(Map<String, dynamic> json) =>
    _$CommentImpl(
      id: json['id'] as String,
      authorId: _readAuthorId(json, 'authorId') as String? ?? '',
      authorUsername:
          _readAuthorUsername(json, 'authorUsername') as String? ?? '',
      authorDisplayName:
          _readAuthorDisplayName(json, 'authorDisplayName') as String? ?? '',
      authorAvatarUrl: _readAuthorAvatar(json, 'authorAvatarUrl') as String?,
      authorDeleted:
          _readAuthorDeleted(json, 'authorDeleted') as bool? ?? false,
      content: json['body'] as String,
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CommentImplToJson(_$CommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'authorUsername': instance.authorUsername,
      'authorDisplayName': instance.authorDisplayName,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'authorDeleted': instance.authorDeleted,
      'body': instance.content,
      'editedAt': instance.editedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
