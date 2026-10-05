// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

/// A board game.
///
/// Parses the backend's `GameSummaryResponse` and `GameDetailResponse`
/// (detail-only fields are null/empty on summaries). The backend exposes a
/// single `playTime`, used for both bounds here.
@freezed
class Game with _$Game {
  const factory Game({
    required String id,
    @JsonKey(name: 'title') required String name,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    int? yearPublished,
    int? minPlayers,
    int? maxPlayers,
    @JsonKey(name: 'playTime') int? minPlayTimeMinutes,
    @JsonKey(readValue: _readPlayTime) int? maxPlayTimeMinutes,
    @JsonKey(name: 'bggRating') double? averageRating,
    @JsonKey(name: 'complexityWeight') double? complexity,
    int? bggId,
    String? bggUrl,
    @Default([]) List<String> categories,
    @Default([]) List<String> mechanics,
    @Default([]) List<String> designers,
    @Default(false) bool hasRulebook,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
}

Object? _readPlayTime(Map<dynamic, dynamic> json, String key) =>
    json['playTime'];
