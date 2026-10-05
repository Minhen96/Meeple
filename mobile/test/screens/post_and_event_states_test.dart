import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

const _zero = '00000000-0000-0000-0000-000000000000';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
  });

  testWidgets('post by a hard-deleted author with several images; report it',
      (tester) async {
    api
      ..get('/api/v1/posts/p4', {
        ...postJson(id: 'p4'),
        'author': {'id': _zero, 'username': null, 'displayName': null,
          'avatarUrl': null, 'deleted': true},
        'imageUrls': ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
      })
      ..get('/api/v1/posts/p4/comments', cursor([]))
      ..post('/api/v1/reports', const FakeResponse(null, status: 201));
    await pumpApp(tester, api: api, location: '/posts/p4');

    expect(find.text('Deleted User'), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('post-menu-p4')));
    await settle(tester);
    expect(find.byKey(const Key('post-menu-delete')), findsNothing);
    await tester.tap(find.byKey(const Key('post-menu-report')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('report-spam')));
    await settle(tester);
    expect(api.calls('POST', '/api/v1/reports').single.data,
        {'targetType': 'post', 'targetId': 'p4', 'reason': 'spam'});
  });

  testWidgets('deleting own post that fails shows an error', (tester) async {
    api
      ..get('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me'))
      ..get('/api/v1/posts/p9/comments', cursor([]))
      ..delete('/api/v1/posts/p9', const FakeResponse.error(500, 'X'));
    await pumpApp(tester, api: api, location: '/posts/p9');
    await tester.tap(find.byKey(const ValueKey('post-menu-p9')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('post-menu-delete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(find.text('Great game night'), findsOneWidget);
  });

  testWidgets('ended event shows memories (empty) ', (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(
        at: DateTime.now().subtract(const Duration(days: 2)),
        status: 'COMPLETED',
      ))
      ..get('/api/v1/posts', cursor([]));
    await pumpApp(tester, api: api, location: '/events/e1');
    expect(find.text('This event has ended.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-memories')));
    await settle(tester);
    expect(find.text('No memories shared yet.'), findsOneWidget);
    expect(api.calls('GET', '/api/v1/posts').single.queryParameters['eventId'],
        'e1');
  });

  testWidgets('ended event memories list posts', (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(
        at: DateTime.now().subtract(const Duration(days: 2)),
        status: 'COMPLETED',
      ))
      ..get('/api/v1/posts', cursor([postJson(id: 'p6', caption: 'Memory!')]));
    await pumpApp(tester, api: api, location: '/events/e1');
    await tester.tap(find.byKey(const Key('event-memories')));
    await settle(tester);
    expect(find.text('Memory!'), findsOneWidget);
  });

  testWidgets('kicked, full and joinable events; deleted host', (tester) async {
    api.get('/api/v1/events/e1', {
      ...eventJson(myRsvp: 'KICKED'),
      'host': {'id': 'h1', 'username': null, 'displayName': null,
        'avatarUrl': null, 'deleted': true},
    });
    final c = await pumpApp(tester, api: api, location: '/events/e1');
    expect(find.text('The host removed you from this event.'), findsOneWidget);
    expect(find.text('Hosted by Deleted User'), findsOneWidget);

    api
      ..get('/api/v1/events/e2', {
        ...eventJson(id: 'e2', myRsvp: null),
        'maxParticipants': 2,
        'participantCount': 2,
      })
      ..get('/api/v1/events/e3', eventJson(id: 'e3', myRsvp: null))
      ..post('/api/v1/events/e3/rsvp', eventJson(id: 'e3'));
    await push(tester, c, '/events/e2');
    expect(find.text('Event is Full'), findsOneWidget);
    await push(tester, c, '/events/e3');
    await tester.tap(find.byKey(const Key('rsvp-join')));
    await settle(tester);
    expect(
      api.calls('POST', '/api/v1/events/e3/rsvp').single.queryParameters,
      {'status': 'ACCEPTED'},
    );
  });
}
