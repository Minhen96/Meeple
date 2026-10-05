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

/// `GET /search` result: `{games, users, events}`.
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

  /// `GET /search?q=&limit=3`. While the unified endpoint is missing, games
  /// and players are searched separately.
  Future<SearchResults> search(String query, {int limit = 3}) => guardApiOr(
        () async {
          final res = await _dio.get<Map<String, dynamic>>(
            ApiConstants.search,
            queryParameters: {'q': query, 'limit': limit},
          );
          return SearchResults.fromJson(res.data ?? const {});
        },
        () async {
          final games = await _dio.get<Map<String, dynamic>>(
            ApiConstants.games,
            queryParameters: {'q': query, 'size': limit},
          );
          final users = await _dio.get<Map<String, dynamic>>(
            '${ApiConstants.users}/search',
            queryParameters: {'q': query, 'size': limit},
          );
          return SearchResults(
            games: (games.data?['content'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(Game.fromJson)
                .toList(),
            users: (users.data?['data'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(UserSummary.fromJson)
                .toList(),
          );
        },
      );
}
