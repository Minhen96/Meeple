import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/push/push_messaging.dart';
import 'package:meeple_hearth/core/push/push_service.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/features/notifications/data/notification_repository.dart';
import 'package:meeple_hearth/features/notifications/data/realtime_service.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

// Streams live for the whole test; nothing to close.
// ignore_for_file: close_sinks

class FakeMessaging implements PushMessaging {
  PushPermission permission = PushPermission.notDetermined;
  PushPermission onRequest = PushPermission.granted;
  String? token = 'fcm-1';
  PushMessage? initial;
  final refresh = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<void> deleteToken() async {}

  @override
  Future<PushMessage?> getInitialMessage() async => initial;

  @override
  Future<PushPermission> getPermission() async => permission;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<PushMessage> get onMessage => messages.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<PushPermission> requestPermission() async =>
      permission = onRequest;
}

class FakeLocal implements LocalNotifications {
  void Function(String?)? onTap;
  final shown = <(String, String, String?)>[];
  String? launch;

  @override
  Future<void> initialize(void Function(String? payload) onTap) async =>
      this.onTap = onTap;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async =>
      shown.add((title, channelId, payload));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late FakeMessaging messaging;
  late FakeLocal local;
  late PushService service;

  setUp(() {
    api = FakeApi()
      ..post('/api/v1/users/me/fcm-tokens', const FakeResponse.noContent())
      ..delete('/api/v1/users/me/fcm-tokens/fcm-1', const FakeResponse.noContent())
      ..delete('/api/v1/users/me/fcm-tokens/fcm-2', const FakeResponse.noContent());
    messaging = FakeMessaging();
    local = FakeLocal();
    service = PushService(
      messaging: messaging,
      local: local,
      repository: NotificationRepository(
        api.dio(),
        AuthSessionManager(SecureStorage()),
      ),
      storage: SecureStorage(),
      platform: 'android',
    );
  });

  group('PushService', () {
    test('disabled without Firebase', () async {
      final off = PushService(
        messaging: null,
        local: null,
        repository: NotificationRepository(
        api.dio(),
        AuthSessionManager(SecureStorage()),
      ),
        storage: SecureStorage(),
      );
      expect(off.isEnabled, isFalse);
      expect(await off.shouldShowPrePrompt(), isFalse);
      expect(await off.requestPermission(), isFalse);
      await off.start();
      await off.stop();
      expect(api.requests, isEmpty);
    });

    test('pre-prompt once, then registers the token after Allow', () async {
      await service.start();
      expect(api.called('POST', '/api/v1/users/me/fcm-tokens'), isFalse);
      expect(await service.shouldShowPrePrompt(), isTrue);

      expect(await service.requestPermission(), isTrue);
      final body =
          api.calls('POST', '/api/v1/users/me/fcm-tokens').single.data as Map;
      expect(body, {'token': 'fcm-1', 'platform': 'android'});
      expect(await service.shouldShowPrePrompt(), isFalse);
    });

    test('Not now suppresses the pre-prompt', () async {
      await service.dismissPrePrompt();
      expect(await service.shouldShowPrePrompt(), isFalse);
    });

    test('granted permission registers on start and on refresh', () async {
      messaging.permission = PushPermission.granted;
      await service.start();
      messaging.refresh.add('fcm-2');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final tokens = api
          .calls('POST', '/api/v1/users/me/fcm-tokens')
          .map((r) => (r.data as Map)['token'])
          .toList();
      expect(tokens, ['fcm-1', 'fcm-2']);

      await service.stop();
      expect(api.called('DELETE', '/api/v1/users/me/fcm-tokens/fcm-2'), isTrue);
    });

    test('foreground messages show on the right channel and taps navigate',
        () async {
      messaging.permission = PushPermission.granted;
      final paths = <String>[];
      final sub = service.navigationRequests.listen(paths.add);
      await service.start();

      messaging.messages.add(const PushMessage(
        title: 'Invite',
        body: 'Join',
        data: {'type': 'EVENT_INVITE', 'path': '/events/e1'},
      ));
      messaging.messages.add(const PushMessage(
        title: 'Like',
        data: {'type': 'POST_LIKE', 'path': '/posts/p1'},
      ));
      await Future<void>.delayed(Duration.zero);
      expect(local.shown, [
        ('Invite', PushChannels.events, '/events/e1'),
        ('Like', PushChannels.social, '/posts/p1'),
      ]);

      local.onTap!('/events/e1');
      messaging.opened.add(const PushMessage(data: {'path': '/posts/p1'}));
      messaging.opened.add(const PushMessage(data: {'path': 'not-a-path'}));
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['/events/e1', '/posts/p1']);
      await sub.cancel();
      await service.dispose();
    });

    test('a launch from a notification is replayed after start', () async {
      messaging.initial = const PushMessage(data: {'path': '/notifications'});
      local.launch = '/events/e2';
      final paths = <String>[];
      final sub = service.navigationRequests.listen(paths.add);
      await service.start();
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['/notifications', '/events/e2']);
      await sub.cancel();
    });
  });

  group('RealtimeService frames', () {
    test('parses {notification, unreadCount} and legacy frames', () async {
      final realtime = RealtimeService(AuthSessionManager(SecureStorage()));
      final received = <RealtimeNotification>[];
      final sub = realtime.notifications.listen(received.add);

      realtime
        ..handleFrameBody(
          '{"notification": {"id":"n1","type":"POST_LIKE","read":false,'
          '"createdAt":"2026-01-01T00:00:00Z","data":{"path":"/posts/p1"}},'
          '"unreadCount": 4}',
        )
        ..handleFrameBody(
          '{"id":"n2","type":"FRIEND_REQUEST","actorId":"u1",'
          '"referenceId":"u1","referenceType":"USER","read":false,'
          '"createdAt":"2026-01-01T00:00:00Z"}',
        )
        ..handleFrameBody('not json')
        ..handleFrameBody(null);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received.first.unreadCount, 4);
      expect(received.first.notification.path, '/posts/p1');
      expect(received.last.unreadCount, isNull);
      expect(received.last.notification.path, '/profile/u1');
      expect(realtime.isConnected, isFalse);
      await sub.cancel();
      realtime.dispose();
    });
  });

  group('AppNotification.path', () {
    AppNotification n(Map<String, dynamic> overrides) => AppNotification.fromJson(
          {...notificationJson(path: null), ...overrides},
        );

    test('derives routes from the reference when data.path is missing', () {
      expect(n({'referenceType': 'EVENT', 'referenceId': 'e1'}).path, '/events/e1');
      expect(n({'referenceType': 'POST', 'referenceId': 'p1'}).path, '/posts/p1');
      expect(n({'referenceType': 'GAME', 'referenceId': 'g1'}).path, '/library/g1');
      expect(n({'referenceType': 'MATCH', 'referenceId': 'm1'}).path, '/matching');
      expect(
        n({'type': 'EVENT_REMINDER', 'referenceType': null, 'referenceId': 'e2'}).path,
        '/events/e2',
      );
      expect(
        n({'type': 'POST_TAG', 'referenceType': 'X', 'referenceId': 'p2'}).path,
        '/posts/p2',
      );
      expect(n({'type': 'OTHER', 'referenceType': 'X', 'referenceId': 'z'}).path, isNull);
      expect(n({'referenceId': null}).path, '/profile/f1');
      expect(n({'data': {'path': '/'}}).path, '/');
    });

    test('RealtimeNotification.tryParse rejects garbage', () {
      expect(RealtimeNotification.tryParse({'notification': {'id': 1}}), isNull);
    });
  });
}
