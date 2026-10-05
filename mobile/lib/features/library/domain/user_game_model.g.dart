// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_game_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserGameImpl _$$UserGameImplFromJson(Map<String, dynamic> json) =>
    _$UserGameImpl(
      id: json['id'] as String?,
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

_$PlayLogImpl _$$PlayLogImplFromJson(Map<String, dynamic> json) =>
    _$PlayLogImpl(
      id: json['id'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      notes: json['notes'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      playerCount: (json['playerCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$PlayLogImplToJson(_$PlayLogImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'playedAt': instance.playedAt.toIso8601String(),
      'notes': instance.notes,
      'durationMinutes': instance.durationMinutes,
      'playerCount': instance.playerCount,
    };

_$FriendGameEntryImpl _$$FriendGameEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$FriendGameEntryImpl(
      user: UserSummary.fromJson(
          readUserOrDeleted(json, 'user') as Map<String, dynamic>),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      personalRating: (json['personalRating'] as num?)?.toDouble(),
      isOwned: json['isOwned'] as bool? ?? false,
    );

Map<String, dynamic> _$$FriendGameEntryImplToJson(
        _$FriendGameEntryImpl instance) =>
    <String, dynamic>{
      'user': instance.user,
      'playCount': instance.playCount,
      'personalRating': instance.personalRating,
      'isOwned': instance.isOwned,
    };

_$GameReviewImpl _$$GameReviewImplFromJson(Map<String, dynamic> json) =>
    _$GameReviewImpl(
      user: UserSummary.fromJson(
          readUserOrDeleted(json, 'user') as Map<String, dynamic>),
      personalRating: (json['personalRating'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$GameReviewImplToJson(_$GameReviewImpl instance) =>
    <String, dynamic>{
      'user': instance.user,
      'personalRating': instance.personalRating,
      'notes': instance.notes,
      'playCount': instance.playCount,
    };

_$HowToPlayImpl _$$HowToPlayImplFromJson(Map<String, dynamic> json) =>
    _$HowToPlayImpl(
      status: json['status'] as String,
      data: json['data'] as Map<String, dynamic>?,
      sourceMode: json['sourceMode'] as String?,
      disclaimer: json['disclaimer'] as String?,
      rulebookUrl: json['rulebookUrl'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$$HowToPlayImplToJson(_$HowToPlayImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'data': instance.data,
      'sourceMode': instance.sourceMode,
      'disclaimer': instance.disclaimer,
      'rulebookUrl': instance.rulebookUrl,
      'progress': instance.progress,
      'errorMessage': instance.errorMessage,
    };

_$BggImportStatusImpl _$$BggImportStatusImplFromJson(
        Map<String, dynamic> json) =>
    _$BggImportStatusImpl(
      status: json['status'] as String? ?? 'idle',
      total: (json['total'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      errorCode: json['errorCode'] as String?,
      preview: (json['preview'] as List<dynamic>?)
              ?.map((e) => BggPreviewGame.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <BggPreviewGame>[],
    );

Map<String, dynamic> _$$BggImportStatusImplToJson(
        _$BggImportStatusImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'total': instance.total,
      'processed': instance.processed,
      'imported': instance.imported,
      'skipped': instance.skipped,
      'failed': instance.failed,
      'errorCode': instance.errorCode,
      'preview': instance.preview,
    };

_$BggPreviewGameImpl _$$BggPreviewGameImplFromJson(Map<String, dynamic> json) =>
    _$BggPreviewGameImpl(
      gameId: json['gameId'] as String,
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );

Map<String, dynamic> _$$BggPreviewGameImplToJson(
        _$BggPreviewGameImpl instance) =>
    <String, dynamic>{
      'gameId': instance.gameId,
      'title': instance.title,
      'thumbnailUrl': instance.thumbnailUrl,
    };
