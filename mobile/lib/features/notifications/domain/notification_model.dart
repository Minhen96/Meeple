// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// `NotificationDto` (GAP §6.1 [WP1]). Also parses the legacy
/// `NotificationResponse` (no actor/title/body/data), in which case the
/// text is built client-side from [type] and [path] is derived.
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String type,
    UserSummary? actor,
    String? actorId,
    String? referenceId,
    String? referenceType,
    String? title,
    String? body,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    @JsonKey(readValue: _readRead) @Default(false) bool read,
    required DateTime createdAt,
  }) = _AppNotification;

  const AppNotification._();

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  /// In-app route to open (FEATURES §12.3), from `data.path` or derived
  /// from the reference.
  String? get path {
    final explicit = data['path'];
    if (explicit is String && explicit.startsWith('/')) return explicit;
    final ref = referenceId;
    // Never route to a deleted account's profile.
    final actorProfile = actor == null || actor!.deleted
        ? null
        : '/profile/${actor!.id}';
    if (ref == null) {
      return type.startsWith('FRIEND_') ? actorProfile : null;
    }
    return switch (referenceType?.toUpperCase()) {
      'EVENT' => '/events/$ref',
      'POST' || 'COMMENT' => '/posts/$ref',
      'GAME' || 'RULEBOOK' || 'RULE_NOTE' => '/library/$ref',
      'USER' || 'FRIEND_REQUEST' => actor == null
          ? (isDeletedUserId(ref) ? null : '/profile/$ref')
          : actorProfile,
      'MATCH' || 'MATCH_GROUP' => '/matching',
      _ => switch (type) {
          final t when t.startsWith('EVENT_') => '/events/$ref',
          final t when t.startsWith('POST_') || t == 'COMMENT_MENTION' =>
            '/posts/$ref',
          final t when t.startsWith('MATCH_') => '/matching',
          _ => null,
        },
    };
  }
}

Object? _readRead(Map<dynamic, dynamic> json, String key) =>
    json['read'] ?? json['isRead'];

/// `/user/queue/notifications` frame (GAP §6.3):
/// `{notification: NotificationDto, unreadCount}`. A bare legacy
/// `NotificationResponse` is accepted too (unread count unknown).
final class RealtimeNotification {
  const RealtimeNotification({required this.notification, this.unreadCount});

  final AppNotification notification;
  final int? unreadCount;

  static RealtimeNotification? tryParse(Map<String, dynamic> json) {
    try {
      final inner = json['notification'];
      if (inner is Map<String, dynamic>) {
        return RealtimeNotification(
          notification: AppNotification.fromJson(inner),
          unreadCount: (json['unreadCount'] as num?)?.toInt(),
        );
      }
      return RealtimeNotification(
        notification: AppNotification.fromJson(json),
      );
    } catch (_) {
      return null;
    }
  }
}

/// `[{type, inAppEnabled, pushEnabled}]`.
@freezed
class NotificationPreference with _$NotificationPreference {
  const factory NotificationPreference({
    required String type,
    @Default(true) bool inAppEnabled,
    @Default(true) bool pushEnabled,
  }) = _NotificationPreference;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferenceFromJson(json);
}

/// `{quietHoursEnabled, quietHoursStart:"HH:mm"|null, quietHoursEnd, timezone}`.
@freezed
class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    @Default(false) bool quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? timezone,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);
}

/// Every type in the NotificationType enum (GAP §6.4), in the order shown
/// on the preferences screen.
const notificationTypes = <String>[
  'EVENT_INVITE',
  'EVENT_RSVP',
  'EVENT_LEAVE',
  'EVENT_KICKED',
  'EVENT_CANCELLED',
  'EVENT_UPDATED',
  'EVENT_REMINDER',
  'EVENT_COMPLETED',
  'MATCH_FOUND',
  'MATCH_ACCEPTED',
  'POST_LIKE',
  'POST_COMMENT',
  'COMMENT_MENTION',
  'POST_TAG',
  'FRIEND_REQUEST',
  'FRIEND_ACCEPTED',
  'RULE_NOTE_APPROVED',
  'RULE_NOTE_REJECTED',
  'RULEBOOK_APPROVED',
  'RULEBOOK_REJECTED',
  'RULEBOOK_UNDER_REVIEW',
  'BGG_IMPORT_COMPLETED',
];
