// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

/// A board game.
///
/// Parses `GameSummaryResponse`, `GameDetailResponse` and `GameSearchResult`
/// (detail-only fields are null/empty on summaries). The backend exposes a
/// single `playTime`, used for both bounds here.
@freezed
class Game with _$Game {
  const factory Game({
    required String id,
    @JsonKey(name: 'title', defaultValue: '') required String name,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    int? yearPublished,
    int? minPlayers,
    int? maxPlayers,
    int? minAge,
    @JsonKey(name: 'playTime') int? minPlayTimeMinutes,
    @JsonKey(readValue: _readPlayTime) int? maxPlayTimeMinutes,
    @JsonKey(name: 'bggRating') double? averageRating,
    @JsonKey(name: 'complexityWeight') double? complexity,
    int? rank,
    int? bggId,
    String? bggUrl,
    @JsonKey(defaultValue: <String>[]) required List<String> categories,
    @JsonKey(defaultValue: <String>[]) required List<String> mechanics,
    @JsonKey(defaultValue: <String>[]) required List<String> designers,
    @JsonKey(defaultValue: <String>[]) required List<String> publishers,
    @Default(false) bool hasRulebook,

    /// GAP §6.1 [WP4] additions to `GameDetailResponse`.
    double? friendAvgRating,
    @Default(0) int friendRatingCount,
    @Default(<UserSummary>[]) List<UserSummary> ownedByFriends,
  }) = _Game;

  const Game._();

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);

  /// Best image for a list tile.
  String? get coverUrl => thumbnailUrl ?? imageUrl;

  /// Hero image for detail pages.
  String? get heroUrl => imageUrl ?? thumbnailUrl;

  /// "2–4" / "2+" / null.
  String? get playersLabel {
    if (minPlayers == null && maxPlayers == null) return null;
    if (minPlayers != null && maxPlayers != null) {
      return minPlayers == maxPlayers
          ? '$minPlayers'
          : '$minPlayers–$maxPlayers';
    }
    return '${minPlayers ?? maxPlayers}+';
  }
}

Object? _readPlayTime(Map<dynamic, dynamic> json, String key) =>
    json['playTime'];
