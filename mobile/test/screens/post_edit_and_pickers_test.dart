// Post edit: playedAt is only sent when changed, unsaved edits ask before
// leaving; pickers resolving after their screen is gone do not crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/router/app_router.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
    api
      ..get('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me'))
      ..get('/api/v1/posts/p9/comments', cursor([]))
      ..put('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me'));
  });

  Map<dynamic, dynamic> putBody() =>
      api.calls('PUT', '/api/v1/posts/p9').single.data as Map;

  group('edit post', () {
    testWidgets('saving without touching the date does not send playedAt',
        (tester) async {
      final c = await pumpApp(tester, api: api, location: '/posts/p9');
      await push(tester, c, '/posts/p9/edit');

      await tester.enterText(find.byKey(const Key('post-caption')), 'Edited');
      await tester.tap(find.byKey(const Key('post-submit')));
      await settle(tester);

      expect(putBody()['caption'], 'Edited');
      expect(putBody().containsKey('playedAt'), isFalse);
      expect(putBody()['location'], 'Cafe');
    });

    testWidgets('a changed play date is sent', (tester) async {
      final c = await pumpApp(tester, api: api, location: '/posts/p9');
      await push(tester, c, '/posts/p9/edit');

      await tester.tap(find.textContaining('Played on'));
      await settle(tester);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('Discard changes?'), findsNothing);
      await tester.tap(find.byKey(const Key('post-submit')));
      await settle(tester);

      final playedAt = DateTime.parse(putBody()['playedAt'] as String);
      expect(playedAt.toLocal().day, 15);
    });

    testWidgets('re-picking the same day is not a change', (tester) async {
      final c = await pumpApp(tester, api: api, location: '/posts/p9');
      await push(tester, c, '/posts/p9/edit');

      await tester.tap(find.textContaining('Played on'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('post-submit')));
      await settle(tester);

      expect(putBody().containsKey('playedAt'), isFalse);
    });

    testWidgets('unsaved edits ask before leaving; untouched edits do not',
        (tester) async {
      final c = await pumpApp(tester, api: api, location: '/posts/p9');
      await push(tester, c, '/posts/p9/edit');

      // Untouched: closes straight away.
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(find.text('Edit post'), findsNothing);

      await push(tester, c, '/posts/p9/edit');
      await tester.enterText(find.byKey(const Key('post-location')), 'Home');
      await settle(tester, 2);
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your edits to this post will be lost.'), findsOneWidget);

      // Keep editing.
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Edit post'), findsOneWidget);

      // Reverting the edit makes the form clean again.
      await tester.enterText(find.byKey(const Key('post-location')), 'Cafe');
      await settle(tester, 2);
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit post'), findsNothing);

      // System back with edits asks too; confirming discards.
      await push(tester, c, '/posts/p9/edit');
      await tester.enterText(find.byKey(const Key('post-caption')), 'Changed');
      await settle(tester, 2);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
      await settle(tester);
      expect(find.text('Edit post'), findsNothing);
      expect(api.called('PUT', '/api/v1/posts/p9'), isFalse);
    });
  });

  group('pickers resolving after the screen is gone', () {
    Future<void> leaveWhilePickerOpen(
      WidgetTester tester,
      String location,
      Key opener,
    ) async {
      final c = await pumpApp(tester, api: api, location: location);
      await tester.tap(find.byKey(opener));
      await settle(tester, 4);
      c.read(appRouterProvider).go('/');
      await settle(tester);
      expect(tester.takeException(), isNull);
    }

    testWidgets('event date', (tester) async {
      await leaveWhilePickerOpen(
        tester,
        '/events/create',
        const Key('event-date'),
      );
    });

    testWidgets('event time', (tester) async {
      await leaveWhilePickerOpen(
        tester,
        '/events/create',
        const Key('event-time'),
      );
    });

    testWidgets('matching availability', (tester) async {
      await leaveWhilePickerOpen(tester, '/matching', const Key('match-from'));
    });
  });
}
