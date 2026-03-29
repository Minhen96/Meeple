// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedItemPostImpl _$$FeedItemPostImplFromJson(Map<String, dynamic> json) =>
    _$FeedItemPostImpl(
      id: json['id'] as String,
      post: Post.fromJson(json['post'] as Map<String, dynamic>),
      feedAt: DateTime.parse(json['feedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$FeedItemPostImplToJson(_$FeedItemPostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'post': instance.post,
      'feedAt': instance.feedAt.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$FeedItemActivityImpl _$$FeedItemActivityImplFromJson(
        Map<String, dynamic> json) =>
    _$FeedItemActivityImpl(
      id: json['id'] as String,
      actorId: json['actorId'] as String,
      actorDisplayName: json['actorDisplayName'] as String,
      actorAvatarUrl: json['actorAvatarUrl'] as String?,
      activityType: json['activityType'] as String,
      description: json['description'] as String,
      targetId: json['targetId'] as String?,
      feedAt: DateTime.parse(json['feedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$FeedItemActivityImplToJson(
        _$FeedItemActivityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'actorId': instance.actorId,
      'actorDisplayName': instance.actorDisplayName,
      'actorAvatarUrl': instance.actorAvatarUrl,
      'activityType': instance.activityType,
      'description': instance.description,
      'targetId': instance.targetId,
      'feedAt': instance.feedAt.toIso8601String(),
      'runtimeType': instance.$type,
    };
