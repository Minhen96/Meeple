import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
    api
      ..get('/api/v1/notifications', cursor([
        notificationJson(),
        notificationJson(
          id: 'n2',
          type: 'POST_LIKE',
          read: true,
          title: 'Fred liked your post',
          path: '/posts/p1',
          at: DateTime.now().subtract(const Duration(days: 3)),
        ),
        notificationJson(
          id: 'n3',
          type: 'EVENT_REMINDER',
          path: null,
          at: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ], next: '2026-01-01T00:00:00Z_n3'))
      ..put('/api/v1/notifications/n1/read', const FakeResponse.noContent())
      ..put('/api/v1/notifications/read-all', const FakeResponse.noContent())
      ..delete('/api/v1/notifications/n1', const FakeResponse.noContent());
  });

  testWidgets('groups notifications and prefers server text', (tester) async {
    await pumpApp(tester, api: api, location: '/notifications');

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Fred sent you a friend request'), findsOneWidget);
    expect(find.text('Fred liked your post'), findsOneWidget);
    expect(find.text('an event starts soon'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-n1')), findsOneWidget);
  });

  testWidgets('cursor is passed back unchanged when loading more',
      (tester) async {
    await pumpApp(tester, api: api, location: '/notifications');
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await settle(tester);

    final cursors = api
        .calls('GET', '/api/v1/notifications')
        .map((r) => r.queryParameters['cursor'])
        .whereType<String>();
    expect(cursors, contains('2026-01-01T00:00:00Z_n3'));
  });

  testWidgets('tapping marks read and opens data.path', (tester) async {
    api.get('/api/v1/users/f1', userJson(id: 'f1', username: 'fred', displayName: 'Fred'));
    await pumpApp(tester, api: api, location: '/notifications');

    await tester.tap(find.text('Fred sent you a friend request'));
    await settle(tester);

    expect(api.called('PUT', '/api/v1/notifications/n1/read'), isTrue);
    expect(api.called('GET', '/api/v1/users/f1'), isTrue);
  });

  testWidgets('mark all read and swipe to delete', (tester) async {
    await pumpApp(tester, api: api, location: '/notifications');

    await tester.tap(find.byKey(const Key('mark-all-read')));
    await settle(tester);
    expect(api.called('PUT', '/api/v1/notifications/read-all'), isTrue);
    expect(find.byKey(const ValueKey('unread-n1')), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('notification-n1')),
      const Offset(-600, 0),
    );
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/notifications/n1'), isTrue);
  });

  testWidgets('empty state', (tester) async {
    api.get('/api/v1/notifications', cursor([]));
    await pumpApp(tester, api: api, location: '/notifications');
    expect(find.text("You're all caught up!"), findsOneWidget);
  });

  testWidgets('preferences toggle and quiet hours', (tester) async {
    api
      ..get('/api/v1/notifications/preferences', [
        {'type': 'POST_LIKE', 'inAppEnabled': true, 'pushEnabled': false},
      ])
      ..put('/api/v1/notifications/preferences', const FakeResponse.noContent())
      ..get('/api/v1/notifications/settings', {
        'quietHoursEnabled': false,
        'quietHoursStart': null,
        'quietHoursEnd': null,
        'timezone': 'Asia/Kuala_Lumpur',
      })
      ..put('/api/v1/notifications/settings', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/settings/notifications');

    expect(find.text('Post liked'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pref-push-POST_LIKE')));
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/notifications/preferences').single;
    final like = (put.data as List)
        .cast<Map<dynamic, dynamic>>()
        .firstWhere((p) => p['type'] == 'POST_LIKE');
    expect(like['pushEnabled'], isTrue);
    expect((put.data as List), hasLength(22));

    await tester.tap(find.byKey(const Key('quiet-hours')));
    await settle(tester);
    final settings =
        api.calls('PUT', '/api/v1/notifications/settings').single.data as Map;
    expect(settings['quietHoursEnabled'], isTrue);
    expect(settings['quietHoursStart'], '22:00');
    expect(settings['quietHoursEnd'], '08:00');
    expect(settings['timezone'], 'Asia/Kuala_Lumpur');
  });
}
