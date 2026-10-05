import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collection_repository.g.dart';

@riverpod
CollectionRepository collectionRepository(CollectionRepositoryRef ref) =>
    CollectionRepository(ref.read(dioProvider));

/// The signed-in user's collection. All write endpoints are keyed by the
/// game's id: `PUT|DELETE /users/me/games/{gameId}`.
final class CollectionRepository {
  const CollectionRepository(this._dio);

  final Dio _dio;

  /// [filter]: `all` | `owned` | `wishlisted` | `favorited`.
  Future<List<UserGame>> getMyCollection({String filter = 'all'}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.myCollection,
        queryParameters: {'filter': filter},
      );
      return response.data!
          .map((e) => UserGame.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Adds or updates a collection entry (`PUT` upsert; only non-null fields
  /// are applied). [personalRating] must be between 1.0 and 10.0.
  Future<UserGame> upsertUserGame({
    required String gameId,
    bool? isOwned,
    bool? isFavorited,
    double? personalRating,
    String? notes,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '${ApiConstants.myCollection}/$gameId',
        data: {
          if (isOwned != null) 'isOwned': isOwned,
          if (isFavorited != null) 'isFavorited': isFavorited,
          if (personalRating != null) 'personalRating': personalRating,
          if (notes != null) 'notes': notes,
        },
      );
      return UserGame.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /users/me/games/{gameId}/log-play` — increments the play count.
  Future<UserGame> logPlay(String gameId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.myCollection}/$gameId/log-play',
      );
      return UserGame.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> removeFromCollection(String gameId) async {
    try {
      await _dio.delete<void>('${ApiConstants.myCollection}/$gameId');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
