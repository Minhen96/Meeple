import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/matching/domain/match_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'match_repository.g.dart';

@riverpod
MatchRepository matchRepository(Ref ref) =>
    MatchRepository(ref.read(dioProvider));

final class MatchRepository {
  const MatchRepository(this._dio);

  final Dio _dio;

  static const _matches = ApiConstants.matches;

  static List<T> _list<T>(
    Object? data,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      (data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();

  /// `POST /matches/requests {gameId, availableFrom, availableTo}`.
  Future<MatchRequest> createRequest({
    required String gameId,
    DateTime? availableFrom,
    DateTime? availableTo,
  }) =>
      guardApi(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_matches/requests',
          data: {
            'gameId': gameId,
            if (availableFrom != null)
              'availableFrom': availableFrom.toUtc().toIso8601String(),
            if (availableTo != null)
              'availableTo': availableTo.toUtc().toIso8601String(),
          },
        );
        return MatchRequest.fromJson(res.data!);
      });

  Future<void> cancelRequest(String requestId) =>
      guardApi(() => _dio.delete<void>('$_matches/requests/$requestId'));

  /// `GET /matches/requests/mine` (alias of `/me`).
  Future<List<MatchRequest>> getMyRequests() => guardApiOr(
        () async => _list(
          (await _dio.get<Object?>('$_matches/requests/mine')).data,
          MatchRequest.fromJson,
        ),
        () async => _list(
          (await _dio.get<Object?>('$_matches/requests/me')).data,
          MatchRequest.fromJson,
        ),
      );

  Future<List<MatchGroup>> getSuggestions() => guardApi(
        () async => _list(
          (await _dio.get<Object?>('$_matches/suggestions')).data,
          MatchGroup.fromJson,
        ),
      );

  /// `POST /matches/{groupId}/accept` → the created event.
  Future<Event> accept(String groupId) => guardApi(() async {
        final res =
            await _dio.post<Map<String, dynamic>>('$_matches/$groupId/accept');
        return Event.fromJson(res.data!);
      });

  Future<void> dismiss(String groupId) =>
      guardApi(() => _dio.post<void>('$_matches/$groupId/dismiss'));
}
