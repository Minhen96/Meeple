import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_repository.g.dart';

@riverpod
SearchRepository searchRepository(Ref ref) =>
    SearchRepository(ref.read(dioProvider));

/// Categories of `GET /search?type=` (the enum names are the wire values).
enum SearchType { all, games, users, events }

/// `GET /search` result: `{games, users, events}` — `GameSummaryResponse`s,
/// `UserSummaryWithStatus`es (with `friendshipStatus`) and `EventSummary`s
/// (`{id, title, scheduledAt, status, visibility, game}`).
final class SearchResults {
  const SearchResults({
    this.games = const [],
    this.users = const [],
    this.events = const [],
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(f)
            .toList();
    return SearchResults(
      games: list('games', Game.fromJson),
      users: list('users', UserSummary.fromJson),
      events: list('events', Event.fromJson),
    );
  }

  final List<Game> games;
  final List<UserSummary> users;
  final List<Event> events;

  bool get isEmpty => games.isEmpty && users.isEmpty && events.isEmpty;
}

final class SearchRepository {
  const SearchRepository(this._dio);

  final Dio _dio;

  /// `GET /search?q=&limit=&type=` → `{games, users, events}`, up to [limit]
  /// (max 20) of each. [type] narrows the search to one category; the other
  /// lists then come back empty.
  Future<SearchResults> search(
    String query, {
    int limit = 3,
    SearchType type = SearchType.all,
  }) =>
      guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          ApiConstants.search,
          queryParameters: {'q': query, 'limit': limit, 'type': type.name},
        );
        return SearchResults.fromJson(res.data ?? const {});
      });
}
