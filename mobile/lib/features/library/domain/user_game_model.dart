// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'user_game_model.freezed.dart';
part 'user_game_model.g.dart';

/// Collection filters accepted by `GET /users/me/games?filter=` (GAP §6.1).
enum CollectionFilter {
  all('all'),
  owned('owned'),
  wishlisted('wishlisted'),
  favorited('favorited');

  const CollectionFilter(this.wire);

  final String wire;
}

/// A game in a user's collection (`UserGameResponse`).
///
/// Multi-boolean model (CLAUDE.md): a game can be owned, wishlisted AND
/// favourited at once. Collection endpoints are keyed by [gameId]
/// (`/users/me/games/{gameId}`), not by [id].
@freezed
class UserGame with _$UserGame {
  const factory UserGame({
    required String id,
    @JsonKey(readValue: _readGameId) required String gameId,
    required Game game,
    @Default(false) bool isOwned,
    @Default(false) bool isWishlisted,
    @Default(false) bool isFavorited,
    @Default(0) int playCount,
    double? personalRating,
    String? notes,
  }) = _UserGame;

  const UserGame._();

  factory UserGame.fromJson(Map<String, dynamic> json) =>
      _$UserGameFromJson(json);

  bool matches(CollectionFilter filter) => switch (filter) {
        CollectionFilter.all => isOwned || isWishlisted || isFavorited,
        CollectionFilter.owned => isOwned,
        CollectionFilter.wishlisted => isWishlisted,
        CollectionFilter.favorited => isFavorited,
      };
}

Object? _readGameId(Map<dynamic, dynamic> json, String key) =>
    json['gameId'] ?? (json['game'] as Map?)?['id'];

/// `POST /users/me/games/{gameId}/plays` → `PlayLogResponse`.
@freezed
class PlayLog with _$PlayLog {
  const factory PlayLog({
    required String id,
    required DateTime playedAt,
    String? notes,
    int? durationMinutes,
    int? playerCount,
  }) = _PlayLog;

  factory PlayLog.fromJson(Map<String, dynamic> json) =>
      _$PlayLogFromJson(json);
}

/// `GET /games/{id}/friends` item.
@freezed
class FriendGameEntry with _$FriendGameEntry {
  const factory FriendGameEntry({
    required UserSummary user,
    @Default(0) int playCount,
    double? personalRating,
    @Default(false) bool isOwned,
  }) = _FriendGameEntry;

  factory FriendGameEntry.fromJson(Map<String, dynamic> json) =>
      _$FriendGameEntryFromJson(json);
}

/// `GET /games/{id}/reviews` item.
@freezed
class GameReview with _$GameReview {
  const factory GameReview({
    required UserSummary user,
    double? personalRating,
    String? notes,
    @Default(0) int playCount,
  }) = _GameReview;

  factory GameReview.fromJson(Map<String, dynamic> json) =>
      _$GameReviewFromJson(json);
}

/// `GET /games/{id}/how-to-play` (`HowToPlayResponse`).
@freezed
class HowToPlay with _$HowToPlay {
  const factory HowToPlay({
    /// `ready` | `generating` | `not_generated` | `failed`.
    required String status,
    Map<String, dynamic>? data,
    String? sourceMode,
    String? disclaimer,
    String? rulebookUrl,
    int? progress,
    String? errorMessage,
  }) = _HowToPlay;

  factory HowToPlay.fromJson(Map<String, dynamic> json) =>
      _$HowToPlayFromJson(json);
}

/// `GET /users/me/bgg-import/status` (GAP §6.1 [WP4]).
@freezed
class BggImportStatus with _$BggImportStatus {
  const factory BggImportStatus({
    /// `idle` | `running` | `done` | `failed`.
    @Default('idle') String status,
    @Default(0) int total,
    @Default(0) int processed,
    @Default(0) int imported,
    @Default(0) int skipped,
    @Default(0) int failed,
    String? errorCode,
  }) = _BggImportStatus;

  const BggImportStatus._();

  factory BggImportStatus.fromJson(Map<String, dynamic> json) =>
      _$BggImportStatusFromJson(json);

  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
}
