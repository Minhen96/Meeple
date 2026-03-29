import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';

part 'user_game_model.freezed.dart';
part 'user_game_model.g.dart';

/// Represents a game in the authenticated user's collection.
///
/// Multi-boolean model: a game can be owned, wishlisted, AND favourited
/// simultaneously. Matches `user_games` table in the DB.
@freezed
class UserGame with _$UserGame {
  const factory UserGame({
    required String id,
    required String userId,
    required String gameId,
    required Game game,
    @Default(false) bool isOwned,
    @Default(false) bool isWishlisted,
    @Default(false) bool isFavorited,
    @Default(0) int playCount,
    int? personalRating,
    String? notes,
    DateTime? lastPlayedAt,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _UserGame;

  factory UserGame.fromJson(Map<String, dynamic> json) =>
      _$UserGameFromJson(json);
}
