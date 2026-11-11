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
    int? usersRated,
    String? gameType,
    int? bggId,
    String? bggUrl,
    @JsonKey(defaultValue: <String>[]) required List<String> categories,
    @JsonKey(defaultValue: <String>[]) required List<String> mechanics,
    @JsonKey(defaultValue: <String>[]) required List<String> designers,
    @JsonKey(defaultValue: <String>[]) required List<String> publishers,
    @Default(<String>[]) List<String> families,
    @Default(<String>[]) List<String> honors,
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

/// Library catalogue browse: search text, discovery filters and sort (web
/// `gamesApi.browse`). Value-equal so it can key a provider family.
final class GameBrowseQuery {
  const GameBrowseQuery({
    this.query = '',
    this.genre,
    this.minPlayers,
    this.maxPlayers,
    this.minPlaytime,
    this.maxPlaytime,
    this.minComplexity,
    this.maxComplexity,
    this.minRating,
    this.sort,
  });

  final String query;
  final String? genre;
  final int? minPlayers;
  final int? maxPlayers;
  final int? minPlaytime;
  final int? maxPlaytime;
  final double? minComplexity;
  final double? maxComplexity;
  final double? minRating;

  /// Spring sort (`rank,asc`, `usersRated,desc`, …) or `recommended`.
  final String? sort;

  /// Number of filter groups in use (the badge on the filter button).
  int get activeFilterCount => [
        genre != null,
        minPlayers != null || maxPlayers != null,
        minPlaytime != null || maxPlaytime != null,
        minComplexity != null || maxComplexity != null,
        minRating != null,
      ].where((on) => on).length;

  GameBrowseQuery copyWith({
    String? query,
    String? Function()? genre,
    int? Function()? minPlayers,
    int? Function()? maxPlayers,
    int? Function()? minPlaytime,
    int? Function()? maxPlaytime,
    double? Function()? minComplexity,
    double? Function()? maxComplexity,
    double? Function()? minRating,
    String? Function()? sort,
  }) =>
      GameBrowseQuery(
        query: query ?? this.query,
        genre: genre == null ? this.genre : genre(),
        minPlayers: minPlayers == null ? this.minPlayers : minPlayers(),
        maxPlayers: maxPlayers == null ? this.maxPlayers : maxPlayers(),
        minPlaytime: minPlaytime == null ? this.minPlaytime : minPlaytime(),
        maxPlaytime: maxPlaytime == null ? this.maxPlaytime : maxPlaytime(),
        minComplexity:
            minComplexity == null ? this.minComplexity : minComplexity(),
        maxComplexity:
            maxComplexity == null ? this.maxComplexity : maxComplexity(),
        minRating: minRating == null ? this.minRating : minRating(),
        sort: sort == null ? this.sort : sort(),
      );

  /// The same search and sort with every filter cleared.
  GameBrowseQuery withoutFilters() => GameBrowseQuery(query: query, sort: sort);

  Map<String, dynamic> toQueryParams() => {
        if (query.isNotEmpty) 'q': query,
        if (genre != null) 'genre': genre,
        if (minPlayers != null) 'minPlayers': minPlayers,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
        if (minPlaytime != null) 'minPlaytime': minPlaytime,
        if (maxPlaytime != null) 'maxPlaytime': maxPlaytime,
        if (minComplexity != null) 'minComplexity': minComplexity,
        if (maxComplexity != null) 'maxComplexity': maxComplexity,
        if (minRating != null) 'minRating': minRating,
        // Popular games first when nothing is searched or sorted.
        if (sort != null) 'sort': sort else if (query.isEmpty) 'sort': 'rank',
      };

  List<Object?> get _props => [
        query,
        genre,
        minPlayers,
        maxPlayers,
        minPlaytime,
        maxPlaytime,
        minComplexity,
        maxComplexity,
        minRating,
        sort,
      ];

  @override
  bool operator ==(Object other) =>
      other is GameBrowseQuery && _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
