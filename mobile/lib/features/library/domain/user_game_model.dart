// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';

part 'user_game_model.freezed.dart';
part 'user_game_model.g.dart';

/// A game in the authenticated user's collection (`UserGameResponse`).
///
/// Multi-boolean model: a game can be owned AND favourited simultaneously.
/// Collection endpoints are keyed by [gameId] (`/users/me/games/{gameId}`),
/// not by [id].
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

  factory UserGame.fromJson(Map<String, dynamic> json) =>
      _$UserGameFromJson(json);
}

Object? _readGameId(Map<dynamic, dynamic> json, String key) =>
    json['gameId'] ?? (json['game'] as Map?)?['id'];
