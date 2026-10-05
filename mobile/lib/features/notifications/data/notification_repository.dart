import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_repository.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) =>
    NotificationRepository(ref.read(dioProvider));

final class NotificationRepository {
  const NotificationRepository(this._dio);

  final Dio _dio;

  static const pageSize = 30;
  static const _base = ApiConstants.notifications;

  /// `GET /notifications?cursor=&limit=30` → `{items, nextCursor, hasMore}`
  /// (legacy `page`/`size` responses are understood too).
  Future<CursorPage<AppNotification>> getNotifications({String? cursor}) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          _base,
          queryParameters: CursorPage.query(cursor, pageSize),
        );
        return CursorPage.fromJson(res.data, AppNotification.fromJson);
      });

  /// `GET /notifications/unread-count` → `{count}`.
  Future<int> getUnreadCount() => guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/unread-count');
        return (res.data?['count'] as num?)?.toInt() ?? 0;
      });

  Future<void> markRead(String id) =>
      guardApi(() => _dio.put<void>('$_base/$id/read'));

  Future<void> markAllRead() =>
      guardApi(() => _dio.put<void>('$_base/read-all'));

  Future<void> delete(String id) =>
      guardApi(() => _dio.delete<void>('$_base/$id'));

  /// `GET /notifications/preferences`. Defaults (everything on) while the
  /// endpoint is missing.
  Future<List<NotificationPreference>> getPreferences() => guardApiOr(
        () async {
          final res = await _dio.get<Object?>('$_base/preferences');
          final byType = {
            for (final p in (res.data as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(NotificationPreference.fromJson))
              p.type: p,
          };
          return [
            for (final type in notificationTypes)
              byType[type] ?? NotificationPreference(type: type),
          ];
        },
        () async => [
          for (final type in notificationTypes)
            NotificationPreference(type: type),
        ],
      );

  Future<void> savePreferences(List<NotificationPreference> prefs) => guardApi(
        () => _dio.put<void>(
          '$_base/preferences',
          data: prefs.map((p) => p.toJson()).toList(),
        ),
      );

  Future<NotificationSettings> getSettings() => guardApiOr(
        () async {
          final res = await _dio.get<Map<String, dynamic>>('$_base/settings');
          return NotificationSettings.fromJson(res.data ?? const {});
        },
        () async => const NotificationSettings(),
      );

  Future<void> saveSettings(NotificationSettings settings) => guardApi(
        () => _dio.put<void>('$_base/settings', data: settings.toJson()),
      );

  // ── Device tokens (FCM) ───────────────────────────────────────────────────

  /// `POST /users/me/fcm-tokens {token, platform, deviceInfo?}` → 204.
  Future<void> registerFcmToken({
    required String token,
    required String platform,
    String? deviceInfo,
  }) =>
      guardApi(
        () => _dio.post<void>(
          ApiConstants.fcmTokens,
          data: {
            'token': token,
            'platform': platform,
            if (deviceInfo != null) 'deviceInfo': deviceInfo,
          },
        ),
      );

  /// `DELETE /users/me/fcm-tokens/{token}` → 204.
  Future<void> unregisterFcmToken(String token) => guardApi(
        () => _dio.delete<void>(
          '${ApiConstants.fcmTokens}/${Uri.encodeComponent(token)}',
        ),
      );
}
