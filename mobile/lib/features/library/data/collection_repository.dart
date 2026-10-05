import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collection_repository.g.dart';

@riverpod
CollectionRepository collectionRepository(Ref ref) =>
    CollectionRepository(ref.read(dioProvider));

/// A user's collection. Write endpoints are keyed by the game's id:
/// `PUT|DELETE /users/me/games/{gameId}`.
final class CollectionRepository {
  const CollectionRepository(this._dio);

  final Dio _dio;

  static const _mine = ApiConstants.myCollection;

  /// `GET /users/me/games?filter=all|owned|wishlisted|favorited`.
  Future<List<UserGame>> getMyCollection({
    CollectionFilter filter = CollectionFilter.all,
  }) =>
      guardApi(() async {
        final res = await _dio.get<List<dynamic>>(
          _mine,
          queryParameters: {'filter': filter.wire},
        );
        return _parse(res.data);
      });

  /// `GET /users/{id}/games?filter=` — another user's public collection.
  Future<List<UserGame>> getUserCollection(
    String userId, {
    CollectionFilter filter = CollectionFilter.owned,
  }) =>
      guardApi(() async {
        final res = await _dio.get<List<dynamic>>(
          '${ApiConstants.users}/$userId/games',
          queryParameters: {'filter': filter.wire},
        );
        return _parse(res.data);
      });

  /// `PUT /users/me/games/{gameId}` upsert; only non-null fields are
  /// applied. [personalRating] must be between 1.0 and 10.0.
  Future<UserGame> upsertUserGame({
    required String gameId,
    bool? isOwned,
    bool? isWishlisted,
    bool? isFavorited,
    double? personalRating,
    String? notes,
  }) =>
      guardApi(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '$_mine/$gameId',
          data: {
            if (isOwned != null) 'isOwned': isOwned,
            if (isWishlisted != null) 'isWishlisted': isWishlisted,
            if (isFavorited != null) 'isFavorited': isFavorited,
            if (personalRating != null) 'personalRating': personalRating,
            if (notes != null) 'notes': notes,
          },
        );
        return UserGame.fromJson(res.data!);
      });

  Future<void> removeFromCollection(String gameId) =>
      guardApi(() => _dio.delete<void>('$_mine/$gameId'));

  /// `POST /users/me/games/{gameId}/plays` (GAP §6.1 [WP4]). Falls back to
  /// the legacy `log-play` increment while the plays endpoint is missing.
  Future<void> logPlay(
    String gameId, {
    DateTime? playedAt,
    String? notes,
    int? durationMinutes,
    int? playerCount,
  }) =>
      guardApiOr(
        () => _dio.post<void>(
          '$_mine/$gameId/plays',
          data: {
            if (playedAt != null)
              'playedAt': playedAt.toUtc().toIso8601String(),
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            if (durationMinutes != null) 'durationMinutes': durationMinutes,
            if (playerCount != null) 'playerCount': playerCount,
          },
        ),
        () => _dio.post<void>('$_mine/$gameId/log-play'),
      );

  /// `GET /users/me/games/{gameId}/plays`.
  Future<List<PlayLog>> getPlays(String gameId) => guardApi(() async {
        final res = await _dio.get<List<dynamic>>('$_mine/$gameId/plays');
        return (res.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlayLog.fromJson)
            .toList();
      });

  /// `DELETE /users/me/plays/{playId}`.
  Future<void> deletePlay(String playId) =>
      guardApi(() => _dio.delete<void>('${ApiConstants.me}/plays/$playId'));

  // ── BGG import ────────────────────────────────────────────────────────────

  /// `POST /users/me/bgg-import {bggUsername}` → 202 `{status:"running"}`.
  Future<void> startBggImport(String bggUsername) => guardApi(
        () => _dio.post<void>(
          '${ApiConstants.me}/bgg-import',
          data: {'bggUsername': bggUsername},
        ),
      );

  /// `GET /users/me/bgg-import/status`.
  Future<BggImportStatus> getBggImportStatus() => guardApi(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('${ApiConstants.me}/bgg-import/status');
        return BggImportStatus.fromJson(res.data!);
      });

  static List<UserGame> _parse(List<dynamic>? data) => (data ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(UserGame.fromJson)
      .toList();
}
