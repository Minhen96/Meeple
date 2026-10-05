// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserSummaryImpl _$$UserSummaryImplFromJson(Map<String, dynamic> json) =>
    _$UserSummaryImpl(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      displayName: _readDisplayName(json, 'displayName') as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      friendshipStatus: json['friendshipStatus'] == null
          ? FriendshipStatus.none
          : FriendshipStatus.parse(json['friendshipStatus']),
    );

Map<String, dynamic> _$$UserSummaryImplToJson(_$UserSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'deleted': instance.deleted,
      'friendshipStatus': _statusToJson(instance.friendshipStatus),
    };
