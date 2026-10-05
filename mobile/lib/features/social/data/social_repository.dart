import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'social_repository.g.dart';

@riverpod
SocialRepository socialRepository(Ref ref) =>
    SocialRepository(ref.read(dioProvider));

/// Friend requests (Facebook model), friends, blocks and reports.
final class SocialRepository {
  const SocialRepository(this._dio);

  final Dio _dio;

  static const pageSize = 30;
  static const _users = ApiConstants.users;
  static const _requests = ApiConstants.friendRequests;

  Future<FriendStatus> getFriendStatus(String userId) => guardApi(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('$_users/$userId/friend-status');
        return FriendStatus.fromJson(res.data ?? const {});
      });

  /// `POST /users/{id}/friend-request` ("Add Friend").
  Future<FriendRequest> sendFriendRequest(String userId) => guardApi(() async {
        final res = await _dio
            .post<Map<String, dynamic>>('$_users/$userId/friend-request');
        return FriendRequest.fromJson(res.data!);
      });

  /// Cancels a request the viewer sent: `DELETE /users/{id}/friend-request`,
  /// or `DELETE /friend-requests/{requestId}` on backends without it.
  Future<void> cancelFriendRequest(String userId, {String? requestId}) =>
      guardApiOr(
        () => _dio.delete<void>('$_users/$userId/friend-request'),
        () async {
          if (requestId == null) throw const NotFoundException();
          await _dio.delete<void>('$_requests/$requestId');
        },
      );

  Future<void> acceptRequest(String requestId) =>
      guardApi(() => _dio.post<void>('$_requests/$requestId/accept'));

  Future<void> declineRequest(String requestId) =>
      guardApi(() => _dio.post<void>('$_requests/$requestId/decline'));

  Future<CursorPage<FriendRequest>> getReceivedRequests({String? cursor}) =>
      _page('$_requests/received', cursor, FriendRequest.fromJson);

  Future<CursorPage<FriendRequest>> getSentRequests({String? cursor}) =>
      _page('$_requests/sent', cursor, FriendRequest.fromJson);

  /// `GET /friends` — the viewer's friends.
  Future<CursorPage<UserSummary>> getFriends({String? cursor}) =>
      _page(ApiConstants.friends, cursor, UserSummary.fromJson);

  Future<void> unfriend(String userId) =>
      guardApi(() => _dio.delete<void>('${ApiConstants.friends}/$userId'));

  Future<void> block(String userId) =>
      guardApi(() => _dio.post<void>('$_users/$userId/block'));

  Future<void> unblock(String userId) =>
      guardApi(() => _dio.delete<void>('$_users/$userId/block'));

  /// `GET /users/me/blocked`.
  Future<List<UserSummary>> getBlocked() => guardApiOr(
        () async {
          final res = await _dio.get<Object?>('${ApiConstants.me}/blocked');
          return CursorPage.fromJson(res.data, UserSummary.fromJson).items;
        },
        () async => const <UserSummary>[],
      );

  /// `POST /reports {targetType, targetId, reason}` → 201.
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) =>
      guardApi(
        () => _dio.post<void>(
          ApiConstants.reports,
          data: {
            'targetType': targetType,
            'targetId': targetId,
            'reason': reason,
          },
        ),
      );

  /// `GET /users/search?q=` (`UserSummaryWithStatus` items).
  Future<List<UserSummary>> searchUsers(String query) => guardApi(() async {
        final res = await _dio.get<Object?>(
          '$_users/search',
          queryParameters: {'q': query, 'size': 20, 'limit': 20},
        );
        return CursorPage.fromJson(res.data, UserSummary.fromJson).items;
      });

  /// `GET /users/suggestions`.
  Future<List<UserSummary>> getSuggestions() => guardApi(() async {
        final res = await _dio.get<Object?>('$_users/suggestions');
        return CursorPage.fromJson(res.data, UserSummary.fromJson).items;
      });

  Future<CursorPage<T>> _page<T>(
    String path,
    String? cursor,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          path,
          queryParameters: CursorPage.query(cursor, pageSize),
        );
        return CursorPage.fromJson(res.data, fromJson);
      });
}
