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

final class CollectionRepository {
  const CollectionRepository(this._dio);

  final Dio _dio;

  Future<List<UserGame>> getMyCollection() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.myCollection);
      return (response.data!)
          .map((e) => UserGame.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<UserGame> addToCollection({
    required String gameId,
    bool isOwned = false,
    bool isWishlisted = false,
    bool isFavorited = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.myCollection,
        data: {
          'gameId': gameId,
          'isOwned': isOwned,
          'isWishlisted': isWishlisted,
          'isFavorited': isFavorited,
        },
      );
      return UserGame.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<UserGame> updateUserGame({
    required String userGameId,
    bool? isOwned,
    bool? isWishlisted,
    bool? isFavorited,
    int? playCount,
    int? personalRating,
    String? notes,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.myCollection}/$userGameId',
        data: {
          if (isOwned != null) 'isOwned': isOwned,
          if (isWishlisted != null) 'isWishlisted': isWishlisted,
          if (isFavorited != null) 'isFavorited': isFavorited,
          if (playCount != null) 'playCount': playCount,
          if (personalRating != null) 'personalRating': personalRating,
          if (notes != null) 'notes': notes,
        },
      );
      return UserGame.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> removeFromCollection(String userGameId) async {
    try {
      await _dio.delete<void>('${ApiConstants.myCollection}/$userGameId');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
