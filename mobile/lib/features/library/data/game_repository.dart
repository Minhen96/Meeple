import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_repository.g.dart';

@riverpod
GameRepository gameRepository(Ref ref) =>
    GameRepository(ref.read(dioProvider));

final class GameRepository {
  const GameRepository(this._dio);

  final Dio _dio;

  static const _games = ApiConstants.games;

  /// Browses cached games (`GET /games?q=&sort=`), a Spring page of
  /// `GameSummaryResponse`. An empty [query] returns the popular games.
  Future<PaginatedResult<Game>> searchGames({
    String query = '',
    PageParams params = const PageParams(),
  }) =>
      guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          _games,
          queryParameters: {
            if (query.isNotEmpty) 'q': query,
            if (query.isEmpty) 'sort': 'rank',
            ...params.toQueryParams(),
          },
        );
        return PaginatedResult.fromJson(
          res.data!,
          (item) => Game.fromJson(item! as Map<String, dynamic>),
        );
      });

  Future<Game> getGame(String gameId) => guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_games/$gameId');
        return Game.fromJson(res.data!);
      });

  /// `GET /games/bgg/{bggId}` — fetches and caches a game from BGG.
  Future<Game> ensureGame(int bggId) => guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_games/bgg/$bggId');
        return Game.fromJson(res.data!);
      });

  /// `GET /games/{id}/friends` — friends who own/played the game.
  /// Empty until the endpoint ships.
  Future<List<FriendGameEntry>> getFriends(String gameId) => guardApiOr(
        () async => _list(
          await _dio.get<Object?>('$_games/$gameId/friends'),
          FriendGameEntry.fromJson,
        ),
        () async => const <FriendGameEntry>[],
      );

  /// `GET /games/{id}/reviews` — friends' ratings and notes.
  Future<List<GameReview>> getReviews(String gameId) => guardApiOr(
        () async => _list(
          await _dio.get<Object?>('$_games/$gameId/reviews'),
          GameReview.fromJson,
        ),
        () async => const <GameReview>[],
      );

  /// `GET /games/{id}/how-to-play`.
  Future<HowToPlay> getHowToPlay(String gameId) => guardApi(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('$_games/$gameId/how-to-play');
        return HowToPlay.fromJson(res.data!);
      });

  /// `POST /games/{id}/how-to-play/generate` — starts generation.
  Future<HowToPlay> generateHowToPlay(String gameId) => guardApi(() async {
        final res = await _dio
            .post<Map<String, dynamic>>('$_games/$gameId/how-to-play/generate');
        return HowToPlay.fromJson(res.data!);
      });

  static List<T> _list<T>(
    Response<Object?> res,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      (res.data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
}
