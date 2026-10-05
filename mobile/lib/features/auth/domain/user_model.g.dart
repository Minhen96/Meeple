// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      displayName: _readDisplayName(json, 'displayName') as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      preferredLanguage: json['preferredLanguage'] as String?,
      timezone: json['timezone'] as String?,
      usernameChangeAvailableAt: json['usernameChangeAvailableAt'] == null
          ? null
          : DateTime.parse(json['usernameChangeAvailableAt'] as String),
      bggUsername: json['bggUsername'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'location': instance.location,
      'onboardingCompleted': instance.onboardingCompleted,
      'isAdmin': instance.isAdmin,
      'isVerified': instance.isVerified,
      'preferredLanguage': instance.preferredLanguage,
      'timezone': instance.timezone,
      'usernameChangeAvailableAt':
          instance.usernameChangeAvailableAt?.toIso8601String(),
      'bggUsername': instance.bggUsername,
      'deleted': instance.deleted,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_$ActiveSessionImpl _$$ActiveSessionImplFromJson(Map<String, dynamic> json) =>
    _$ActiveSessionImpl(
      id: json['id'] as String,
      deviceInfo: json['deviceInfo'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
      current: json['current'] as bool? ?? false,
    );

Map<String, dynamic> _$$ActiveSessionImplToJson(_$ActiveSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceInfo': instance.deviceInfo,
      'createdAt': instance.createdAt?.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'current': instance.current,
    };
