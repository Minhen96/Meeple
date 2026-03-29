import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

@freezed
class Game with _$Game {
  const factory Game({
    required String id,
    required String name,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    int? minPlayers,
    int? maxPlayers,
    int? minPlayTimeMinutes,
    int? maxPlayTimeMinutes,
    double? averageRating,
    int? bggId,
    String? bggUrl,
    @Default([]) List<String> categories,
    @Default([]) List<String> mechanics,
    @Default([]) List<String> designers,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
}
