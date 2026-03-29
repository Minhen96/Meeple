import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_repository.g.dart';

@riverpod
GameRepository gameRepository(GameRepositoryRef ref) =>
    GameRepository(ref.read(dioProvider));

final class GameRepository {
  const GameRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<Game>> searchGames({
    required String query,
    PageParams params = const PageParams(),
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.games,
        queryParameters: {
          'q': query,
          ...params.toQueryParams(),
        },
      );
      return PaginatedResult.fromJson(
        response.data!,
        (item) => Game.fromJson(item as Map<String, dynamic>),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Game> getGame(String gameId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.games}/$gameId',
      );
      return Game.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
