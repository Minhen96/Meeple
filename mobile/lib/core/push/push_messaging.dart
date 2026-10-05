import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification permission state, platform independent.
enum PushPermission { granted, denied, notDetermined }

/// A received push message (FCM `RemoteMessage`), reduced to what the app
/// uses: the visible text and `data.path` for deep links.
final class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  factory PushMessage.fromRemote(RemoteMessage m) => PushMessage(
        title: m.notification?.title ?? m.data['title'] as String?,
        body: m.notification?.body ?? m.data['body'] as String?,
        data: m.data,
      );

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  String? get path {
    final p = data['path'];
    return p is String && p.startsWith('/') ? p : null;
  }

  String? get type => data['type'] as String?;
}

/// The Firebase Messaging surface used by [PushService] (fakeable in tests).
abstract interface class PushMessaging {
  Future<PushPermission> getPermission();
  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onMessage;
  Stream<PushMessage> get onMessageOpenedApp;
  Future<PushMessage?> getInitialMessage();
}

/// Foreground banners via flutter_local_notifications (fakeable in tests).
abstract interface class LocalNotifications {
  /// Creates the Android channels and registers [onTap] (payload = path).
  Future<void> initialize(void Function(String? payload) onTap);

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  });

  /// Payload of the local notification that launched the app, if any.
  Future<String?> launchPayload();
}

PushPermission _fromStatus(AuthorizationStatus s) => switch (s) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermission.granted,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };

/// [PushMessaging] backed by `FirebaseMessaging.instance`. Only construct
/// it after Firebase was initialised.
final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging() : _fm = FirebaseMessaging.instance;

  final FirebaseMessaging _fm;

  @override
  Future<PushPermission> getPermission() async =>
      _fromStatus((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async => _fromStatus(
        (await _fm.requestPermission(alert: true, badge: true, sound: true))
            .authorizationStatus,
      );

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Future<void> deleteToken() => _fm.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(PushMessage.fromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : PushMessage.fromRemote(m);
  }
}

/// Android notification channels (MOBILE_FLUTTER §8).
abstract final class PushChannels {
  static const events = 'meeple_hearth_events';
  static const social = 'meeple_hearth_social';

  /// Events, matches and reminders are urgent; everything else is social.
  static String forType(String? type) =>
      type != null && (type.startsWith('EVENT_') || type.startsWith('MATCH_'))
          ? events
          : social;
}

/// [LocalNotifications] backed by flutter_local_notifications.
final class PluginLocalNotifications implements LocalNotifications {
  PluginLocalNotifications({
    required this.eventsChannelName,
    required this.eventsChannelDescription,
    required this.socialChannelName,
    required this.socialChannelDescription,
  });

  final String eventsChannelName;
  final String eventsChannelDescription;
  final String socialChannelName;
  final String socialChannelDescription;

  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested through FCM after the pre-prompt.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload),
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          PushChannels.events,
          eventsChannelName,
          description: eventsChannelDescription,
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          PushChannels.social,
          socialChannelName,
          description: socialChannelDescription,
        ),
      );
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) =>
      _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == PushChannels.events
                ? eventsChannelName
                : socialChannelName,
            importance: channelId == PushChannels.events
                ? Importance.high
                : Importance.defaultImportance,
            priority: channelId == PushChannels.events
                ? Priority.high
                : Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false
        ? details!.notificationResponse?.payload
        : null;
  }
}
