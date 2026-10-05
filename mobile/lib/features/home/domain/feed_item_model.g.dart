// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedPostItemImpl _$$FeedPostItemImplFromJson(Map<String, dynamic> json) =>
    _$FeedPostItemImpl(
      createdAt: DateTime.parse(json['createdAt'] as String),
      post: Post.fromJson(json['post'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$$FeedPostItemImplToJson(_$FeedPostItemImpl instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt.toIso8601String(),
      'post': instance.post,
      'kind': instance.$type,
    };

_$FeedActivityItemImpl _$$FeedActivityItemImplFromJson(
        Map<String, dynamic> json) =>
    _$FeedActivityItemImpl(
      createdAt: DateTime.parse(json['createdAt'] as String),
      activity: FeedActivity.fromJson(json['activity'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$$FeedActivityItemImplToJson(
        _$FeedActivityItemImpl instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt.toIso8601String(),
      'activity': instance.activity,
      'kind': instance.$type,
    };

_$FeedUnknownItemImpl _$$FeedUnknownItemImplFromJson(
        Map<String, dynamic> json) =>
    _$FeedUnknownItemImpl(
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$$FeedUnknownItemImplToJson(
        _$FeedUnknownItemImpl instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt?.toIso8601String(),
      'kind': instance.$type,
    };

_$FeedActivityImpl _$$FeedActivityImplFromJson(Map<String, dynamic> json) =>
    _$FeedActivityImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      data: json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$$FeedActivityImplToJson(_$FeedActivityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'user': instance.user,
      'data': instance.data,
    };
