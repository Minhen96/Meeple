import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_repository.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) =>
    NotificationRepository(
      ref.read(dioProvider),
      ref.read(authSessionManagerProvider),
    );

final class NotificationRepository {
  const NotificationRepository(this._dio, this._session);

  final Dio _dio;
  final AuthSessionManager _session;

  static const pageSize = 30;
  static const _base = ApiConstants.notifications;

  /// `GET /notifications?cursor=&limit=30` → `{items, nextCursor, hasMore}`
  /// (legacy `page`/`size` responses are understood too). Items are
  /// `NotificationResponse`s whose `actor` is null-safe for deleted users.
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

  /// `GET /notifications/preferences` → `[{type, inAppEnabled,
  /// pushEnabled}]`, completed with defaults (everything on) for any type the
  /// server did not list, in [notificationTypes] order.
  Future<List<NotificationPreference>> getPreferences() => guardApi(() async {
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
      });

  Future<void> savePreferences(List<NotificationPreference> prefs) => guardApi(
        () => _dio.put<void>(
          '$_base/preferences',
          data: prefs.map((p) => p.toJson()).toList(),
        ),
      );

  /// `GET /notifications/settings` → `{quietHoursEnabled, quietHoursStart,
  /// quietHoursEnd, timezone}`.
  Future<NotificationSettings> getSettings() => guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/settings');
        return NotificationSettings.fromJson(res.data ?? const {});
      });

  Future<void> saveSettings(NotificationSettings settings) => guardApi(
        () => _dio.put<void>('$_base/settings', data: settings.toJson()),
      );

  // ── Device tokens (FCM) ───────────────────────────────────────────────────

  /// The backend links a device token to this device's session family by
  /// the refresh-token cookie, so `revoke-others` keeps this phone's token.
  Future<Options> _sessionOptions() async =>
      Options(headers: await _session.sessionCookieHeader());

  /// `POST /users/me/fcm-tokens {token, platform, deviceInfo?}` → 204, with
  /// the `refresh_token` cookie of this device's session.
  Future<void> registerFcmToken({
    required String token,
    required String platform,
    String? deviceInfo,
  }) =>
      guardApi(
        () async => _dio.post<void>(
          ApiConstants.fcmTokens,
          options: await _sessionOptions(),
          data: {
            'token': token,
            'platform': platform,
            if (deviceInfo != null) 'deviceInfo': deviceInfo,
          },
        ),
      );

  /// `DELETE /users/me/fcm-tokens/{token}` → 204 (with the session cookie).
  Future<void> unregisterFcmToken(String token) => guardApi(
        () async => _dio.delete<void>(
          '${ApiConstants.fcmTokens}/${Uri.encodeComponent(token)}',
          options: await _sessionOptions(),
        ),
      );
}
